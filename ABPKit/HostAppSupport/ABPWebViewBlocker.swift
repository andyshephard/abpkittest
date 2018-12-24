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
    public var user: User!
    var bag: DisposeBag!
    var ctrl: WKUserContentController!
    var ruleListID: String?
    var wkcb: WebKitContentBlocker!
    weak var host: ABPBlockable!

    public
    init(host: ABPBlockable) throws {
        bag = DisposeBag()
        self.host = host
        wkcb = WebKitContentBlocker()
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
            host.webView.load(URLRequest(url: url))
            completion(url, nil)
        } else {
            completion(nil, ABPWebViewBlockerError.badURL)
        }
    }

    /// Add rules for the user's block list.
    /// Remove rules in the store that are not in user history.
    public
    func addNewRuleList(completion: @escaping ([Error]?) -> Void) {
        var errors = [Error]()
        wkcb.rulesAddedWKStore(user: self.user)
            .flatMap { _ -> Observable<WKContentRuleList> in
                return self.rulesAddToContentController()
            }
            .flatMap { _ -> Observable<Observable<String>> in
                return self.wkcb.syncHistoryRemovers(user: self.user)
            }
            .flatMap { removed -> Observable<String> in
                return removed
            }
            .subscribe(onError: { err in
                errors.append(err)
                completion(errors)
            }, onCompleted: {
                if errors.count == 0 {
                    completion(nil)
                } else {
                    completion(errors)
                }
            }).disposed(by: bag)
    }

    /// Add rules if an entry in user history matches the existing rule lists in
    /// the store.
    public
    func addExistingRuleList(completion: @escaping (Bool) -> Void) throws {
        guard let blst = user.blockList else { throw ABPUserModelError.badDataUser }
        let mtch = try UserStateHelper(user: user).historyMatch()(blst.source)
        rulesUseWithContentController(blockList: mtch)
            .subscribe(onNext: { lists in
                self.wkcb.rulesStore
                    .getAvailableContentRuleListIdentifiers { ids in
                        // Complete with true if there is a unique match.
                        completion(lists.count > 0 && ids?.filter { $0 == mtch?.name }.count == 1)
                    }
            }, onError: { _ in
                // Lookup error may have occurred. Try to clear rules to recover:
                self.clearRules {
                    completion(false)
                }
            }).disposed(by: bag)
    }

    /// Clear all rules in store.
    func clearRules(completion: @escaping () -> Void) {
        wkcb.clearedRules(user: user, clearAll: true)
            .subscribe(onNext: { _ in
                completion()
            }, onError: { _ in
                completion()
            }).disposed(by: bag)
    }

    /// Adds one rule list to the content controller if they exist for the
    /// user's current block list.
    private
    func rulesAddToContentController() -> Observable<WKContentRuleList> {
        guard let user = self.user, let name = user.blockList?.name else {
            return Observable.error(ABPUserModelError.badDataUser)
        }
        return Observable.create { observer in
            // Remove lists from content controller:
            self.ctrl.removeAllContentRuleLists()
            self.wkcb.rulesStore
                .lookUpContentRuleList(forIdentifier: name) { list, err in
                    if err != nil { observer.onError(err!) }
                    if list != nil {
                        self.ctrl.add(list!)
                        do { try self.user.updateHistory().save() } catch let err { observer.onError(err) }
                        observer.onNext(list!)
                        observer.onCompleted()
                    }
                }
            return Disposables.create()
        }
    }

    /// Add rules to content controller.
    /// Return array with blocklist added so that dupes can be checked.
    private
    func rulesUseWithContentController(blockList: BlockList?) -> Observable<[BlockList]> {
        var result = [BlockList]()
        guard let blst = blockList else { return Observable.just(result) }
        return Observable.create { observer in
            self.wkcb.rulesStore
                .lookUpContentRuleList(forIdentifier: blst.name) { rlist, err in
                    if err != nil {
                        observer.onError(err!)
                    }
                    if rlist != nil {
                        self.ctrl.add(rlist!)
                        result.append(blst)
                    }
                    observer.onNext(result)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }
}
