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

/// Block ads in a WKWebView.
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
    /// For debugging: Don't use remote rules when true.
    var noRemote = false
    var ruleListID: String?
    var wkcb: WebKitContentBlocker!
    weak var host: ABPBlockable!

    public
    init(host: ABPBlockable) throws {
        bag = DisposeBag()
        self.host = host
        wkcb = WebKitContentBlocker(logWith: { log("📙store \($0 as [String]?)") })
        ctrl = host.webView.configuration.userContentController
        do {
            user = try User(fromPersistentStorage: true)
        } catch let err { throw err }
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

    /// Use bundled or downloaded rule list, as needed.
    /// Error handling is not complete yet.
    public
    func userListAutoActivate(reportStatusSwitch: (() -> Void)?,
                              logUser: ((User) -> Void)?,
                              loadURL: @escaping () -> Void,
                              finally: (() -> Void)? = nil) {
        var statusSwitchShow = false
        let start = Date()
        fromExistingOrNewRuleList()
            .takeLast(1) // due to multiple removes
            .flatMap { _ -> Observable<User> in
                log("⏱️\(fabs(start.timeIntervalSinceNow))")
                loadURL()
                let shlp = SourceHelper()
                if let src = shlp.userSourceable(self.user), !shlp.isRemote()(src) && !self.noRemote {
                    statusSwitchShow = true
                    return self.withRemoteBL(self.user.acceptableAdsInUse())
                } else { return Observable.just(self.user) }
            }
            .flatMap { user -> Observable<WKContentRuleList> in
                do { // state change to remote BL after DLs
                    self.user = try self.userUpdatedFromDownloads()(user).saved()
                } catch let err { log("🚨 Error during DL update: \(err)") }
                logUser?(self.user)
                return self.wkcb.rulesAddedWKStore(user: self.user)
            }
            .subscribe(onNext: { _ in
                if statusSwitchShow {
                    loadURL()
                    reportStatusSwitch?()
                }
            }, onError: { err in
                log("🚨 Error during auto activate: \(err)")
            }, onCompleted: {
                do {
                    try self.syncDownloads()
                } catch let err { log("🚨 Error on completed: \(err)") }
                finally?()
            }).disposed(by: bag)
    }

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
        self.user = try UserBlockListDownloader(
            user: self.user,
            logWith: { log("🗑️\($0)") })
                .syncDownloads()(self.user).saved()
    }

    // swiftlint:disable unused_closure_parameter
    /// Add rules from history or user's blocklist.
    public
    func fromExistingOrNewRuleList() -> Observable<WKContentRuleList?> {
        guard let blst = user.blockList else { return Observable.error(ABPUserModelError.badDataUser) }
        var existing: BlockList?
        var added: WKContentRuleList?
        do {
            existing = try UserStateHelper(user: user).historyMatch()(blst.source)
            // Download matching is not handled here.
        } catch let err { return Observable.error(err) }
        if existing != nil {
            // Use existing rules in the store:
            return rulesUseWithContentController(blockList: existing)
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
        // Add new rules to the store:
        return wkcb.rulesAddedWKStore(user: self.user)
            .flatMap { _ -> Observable<WKContentRuleList> in
                return self.rulesAddToContentController()
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
        if let blst = self.user.blockList?.source, SourceHelper().isRemote()(blst) {
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

    /// Adds a rule list to the content controller if it exists for the user's
    /// current block list.
    private
    func rulesAddToContentController() -> Observable<WKContentRuleList> {
        guard let blst = user.blockList else {
            return Observable.error(ABPUserModelError.badDataUser)
        }
        return Observable.create { observer in
            // Remove all existing before adding:
            self.ctrl.removeAllContentRuleLists()
            self.wkcb.rulesStore
                .lookUpContentRuleList(forIdentifier: blst.name) { list, err in
                    if err != nil { observer.onError(err!) }
                    if list != nil {
                        self.ctrl.add(list!)
                        do {
                            self.user = try self.user.historyUpdated().saved()
                        } catch let err { observer.onError(err) }
                        observer.onNext(list!)
                        observer.onCompleted()
                    }
                }
            return Disposables.create()
        }
    }

    /// Add rules for a block list to the content controller. Return name of
    /// list added.
    private
    func rulesUseWithContentController(blockList: BlockList?) -> Observable<WKContentRuleList?> {
        guard let blst = blockList else { return Observable.just(nil) }
        return Observable.create { observer in
            self.wkcb.rulesStore
                .lookUpContentRuleList(forIdentifier: blst.name) { rlist, err in
                    if err != nil { observer.onError(err!) }
                    if let list = rlist {
                        self.ctrl.add(list)
                        do {
                            self.user = try self.user.historyUpdated().saved()
                        } catch let err { observer.onError(err) }
                        observer.onNext(list)
                        observer.onCompleted()
                    }
                    observer.onNext(nil)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }
}
