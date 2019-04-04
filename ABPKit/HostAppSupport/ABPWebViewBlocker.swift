/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import RxSwift
import WebKit

@available(iOS 11.0, macOS 10.13, *)
public
protocol ABPBlockable: class {
    var webView: WKWebView! { get }
}

/// Block ads in a WKWebView for framework adopters.
@available(iOS 11.0, macOS 10.13, *)
public
class ABPWebViewBlocker {
    public let lastUser: () throws -> User = {
        if let user = try User(fromPersistentStorage: true) { return user }
        throw ABPUserModelError.badDataUser
    }
    public var user: User!
    /// For async.
    let scheduler = SerialDispatchQueueScheduler(qos: .userInitiated)
    var bag: DisposeBag!
    var ctrl: WKUserContentController!
    /// Log file removals during user state syncing if true.
    var logFileRemovals = false
    /// For debugging: Don't use remote rules when true.
    var noRemote: Bool!
    var ruleListID: String?
    var wkcb: WebKitContentBlocker!
    weak var host: ABPBlockable!

    /// Uses a given user state.
    public
    init(host: ABPBlockable,
         user: User,
         noRemote: Bool = false,
         logFileRemovals: Bool = false) throws {
        bag = DisposeBag()
        self.host = host
        self.logFileRemovals = logFileRemovals
        self.noRemote = noRemote
        wkcb = WebKitContentBlocker(logWith: { log("📙store \($0 as [String]?)") })
        ctrl = host.webView.configuration.userContentController
        self.user = user
    }

    deinit {
        bag = nil
    }

    public
    func loadURLString(_ urlString: String,
                       completion: (URL?, Error?) -> Void) {
        let newString = urlString.addingWebProtocol()
        if let url = URL(string: newString) {
            DispatchQueue.main.async {
                self.host.webView.load(URLRequest(url: url))
            }
            completion(url, nil)
        } else {
            completion(nil, ABPWebViewBlockerError.badURL)
        }
    }

    /// Activate bundled or downloaded rule list, as needed.
    public
    func useContentBlocking(logPreparationTime: Bool = false,
                            logBlockListSwitch: (() -> Void)? = nil,
                            logUserState: ((User) -> Void)? = nil,
                            completeWith: @escaping (Error?) -> Void) {
        var statusSwitchShow = false
        let start = Date()
        fromExistingOrNewRuleList()
            .takeLast(1) // due to multiple removes
            .flatMap { _ -> Observable<User> in
                if logPreparationTime { log("⏱️\(fabs(start.timeIntervalSinceNow))") }
                completeWith(nil)
                let shlp = SourceHelper()
                if let src = shlp.userSourceable(self.user), !shlp.isRemote()(src) && !self.noRemote {
                    statusSwitchShow = true
                    return self.withRemoteBL(self.user.acceptableAdsInUse())
                } else { return Observable.just(self.user) }
            }
            .flatMap { user -> Observable<WKContentRuleList> in
                do { // state change to remote BL after DLs
                    self.user = try self.userUpdatedFromDownloads()(user).saved()
                } catch let err { completeWith(err) }
                logUserState?(self.user)
                return self.wkcb.rulesAddedWKStore(user: self.user)
            }
            .subscribe(onNext: { _ in
                if statusSwitchShow {
                    logBlockListSwitch?()
                }
            }, onError: { err in
                completeWith(err)
            }, onCompleted: {
                do {
                    try self.syncDownloads()
                } catch let err { completeWith(err) }
                completeWith(nil)
            }).disposed(by: bag)
    }

    /// Update user's blocklist to a new downloaded blocklist.
    func userUpdatedFromDownloads() -> (User) throws -> User {
        return { user in
            if let blst = user.getBlockList(),
               let match = try UserStateHelper(user: user).downloadsMatch()(blst.source) {
                return user.blockListSet()(match)
            }
            throw ABPUserModelError.badDownloads
        }
    }

    public
    func syncDownloads() throws {
        self.user = try UserBlockListDownloader(user: user, logWith: logFileRemovals ? { log("🗑️\($0)") } : nil)
            .syncDownloads()(self.user).saved()
    }

    // swiftlint:disable unused_closure_parameter
    /// Add rules from history or user's blocklist.
    public
    func fromExistingOrNewRuleList() -> Observable<WKContentRuleList?> {
        guard let blst = user.blockList else {
            return Observable.error(ABPUserModelError.badDataUser)
        }
        var existing: BlockList?
        do {
            existing = try UserStateHelper(user: user).historyMatch()(blst.source)
            // Download matching is not handled here.
        } catch let err { return Observable.error(err) }
        var added: WKContentRuleList?
        // Remove all before adds - Removal requires main thread operation:
        DispatchQueue.main.async { [weak self] in
            self?.ctrl.removeAllContentRuleLists()
        }
        if existing != nil {
            // Use existing rules in the store:
            return contentControllerAddBlocklistable()(existing)
                .flatMap { blst -> Observable<Observable<String>> in
                    added = blst
                    return self.wkcb.syncHistoryRemovers(user: self.user)
                }
                .flatMap { remove -> Observable<String> in
                    return remove
                }
                .flatMap { removed -> Observable<WKContentRuleList?> in
                    return Observable.just(added)
                }.observeOn(scheduler)
        }
        // Add new rules to the store:
        return wkcb.rulesAddedWKStore(user: self.user)
            .flatMap { _ -> Observable<WKContentRuleList?> in
                return self.contentControllerAddBlocklistable()(blst)
            }
            .flatMap { list -> Observable<Observable<String>> in
                added = list
                return self.wkcb.syncHistoryRemovers(user: self.user)
            }
            .flatMap { remove -> Observable<String> in
                return remove
            }
            .flatMap { removed -> Observable<WKContentRuleList?> in
                return Observable.just(added)
            }.observeOn(scheduler)
    }
    // swiftlint:enable unused_closure_parameter

    /// User state blocklist is switched to a placeholder remote source with the
    /// AA state of the user passed in. Returns user state after downloads.
    public
    func withRemoteBL(_ aaInUse: Bool) -> Observable<User> {
        // Don't DL if remote src is being used.
        if let src = self.user.blockList?.source, SourceHelper().isRemote()(src) {
            return Observable.just(self.user)
        }
        var user: User!
        do {
            user = try User(
                fromPersistentStorage: true,
                withBlockList: BlockList(
                    withAcceptableAds: aaInUse,
                    source: SourceHelper().remoteSourceForAA()(aaInUse)))
        } catch let err { return Observable.error(err) }
        let dler = UserBlockListDownloader(user: user)
        return dler.userAfterDownloads()(dler.userSourceDownloads())
            .observeOn(self.scheduler)
    }

    /// Add rules for a Blocklistable to the content controller. Return list added.
    private
    func contentControllerAddBlocklistable<U: BlockListable>() -> (U?) -> Observable<WKContentRuleList?> {
        return {
            guard let ulst = $0 else { return Observable.empty() }
            return Observable.create { observer in
                self.wkcb.rulesStore.lookUpContentRuleList(forIdentifier: ulst.name) { rlist, err in
                    if err != nil { observer.onError(err!) }
                    do {
                        try observer.onNext(self.toContentControllerAdd()(rlist))
                        self.user = try self.user.historyUpdated().saved() // state change
                    } catch let err { observer.onError(err) }
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
    }

    /// The only adder for the content controller.
    private
    func toContentControllerAdd() -> (WKContentRuleList?) throws -> WKContentRuleList? {
        return { if $0 != nil { self.ctrl.add($0!); return $0! }; return nil }
    }
}
