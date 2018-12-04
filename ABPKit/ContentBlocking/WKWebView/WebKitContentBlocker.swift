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
class WebKitContentBlocker {
    let cfg = Config()
    var bag: DisposeBag!
    var bundle: Bundle?
    var rulesStore: WKContentRuleListStore!

    init?() {
        bag = DisposeBag()
        guard let rulesStore = (try? WKContentRuleListStore(url: cfg.rulesStoreIdentifier()))
            as? WKContentRuleListStore else { return nil }
        self.rulesStore = rulesStore
    }

    /// From user's block list, make a rule list and it to the store.
    func rulesAddedWKStore(user: User) -> Observable<WKContentRuleList> {
        return concatenatedRules(user: user)
            .flatMap { result -> Observable<WKContentRuleList> in
                return self.rulesCompiled(user: user, rules: result.0)
            }
            .flatMap { list -> Observable<WKContentRuleList> in
                return self.ruleListVerified(user: user, list: list)
            }
    }

    func ruleListVerified(user: User, list: WKContentRuleList) -> Observable<WKContentRuleList> {
        return ruleIdentifiers()
            .flatMap { ids -> Observable<WKContentRuleList> in
                return Observable.create { observer in
                    if let blst = user.blockList,
                       blst.name != list.identifier ||
                       ids?.contains(blst.name) == false { observer.onError(ABPWKRuleStoreError.invalidData) }
                    ABPKit.log("📙store \(String(describing: ids))")
                    observer.onNext(list)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }

    /// Wrapper for ids.
    func ruleIdentifiers() -> Observable<[String]?> {
        return Observable.create { observer in
            self.rulesStore
                .getAvailableContentRuleListIdentifiers { ids in
                    observer.onNext(ids)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }

    /// Wrapper for rules compile.
    /// Rules should match the user's block list.
    func rulesCompiled(user: User, rules: String) -> Observable<WKContentRuleList> {
        return Observable.create { observer in
            self.rulesStore
                .compileContentRuleList(forIdentifier: user.blockList?.name,
                                        encodedContentRuleList: rules) { list, err in
                    guard err == nil else { observer.onError(err!); return }
                    if list != nil {
                        observer.onNext(list!)
                        observer.onCompleted()
                    } else {
                       observer.onError(ABPWKRuleStoreError.invalidData)
                    }
                }
            return Disposables.create()
        }
    }

    /// Correct state is rule store is less than or equal to user history.
    /// Rules are added from user history.
    func syncHistoryRemovers(user: User) -> Observable<Observable<String>> {
        guard let hist = user.blockListHistory else {
            return Observable.error(ABPWKRuleStoreError.invalidData)
        }
        var obs = [Observable<String>]()
        return ruleIdentifiers()
            .flatMap { ids -> Observable<Observable<String>> in
                return Observable.create { observer in
                    // Add remove if identifier in store is not in the user's history.
                    if ids != nil {
                        obs = ids!.filter { idr in !hist.contains { $0.name == idr } }
                            .map { return self.listRemovedFromStore(identifier: $0) }
                    }
                    observer.onNext(Observable.concat(obs))
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }

    func listRemovedFromStore(identifier: String) -> Observable<String> {
        return Observable.create { observer in
            self.rulesStore
                .removeContentRuleList(forIdentifier: identifier) { err in
                    // Remove for identifier complete.
                    if err != nil { observer.onError(err!) }
                    observer.onNext(identifier)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }

    /// Based on FilterList. Returns an observable after adding.
    /// This function is now only for reference and testing.
    /// The User model should be preferred over FilterList.
    func addedWKStoreRules(addList: FilterList) -> Observable<WKContentRuleList> {
        return concatenatedRules(model: addList)
            .flatMap { result -> Observable<WKContentRuleList> in
                return Observable.create { observer in
                    self.rulesStore
                        .compileContentRuleList(forIdentifier: addList.name,
                                                encodedContentRuleList: result.0) { list, err in
                            guard err == nil else {
                                observer.onError(err!); return
                            }
                            self.rulesStore.getAvailableContentRuleListIdentifiers { (ids: [String]?) in
                                if let name = addList.name,
                                   ids?.contains(name) == false { observer.onError(ABPWKRuleStoreError.missingRuleList) }
                                ABPKit.log("📙 \(String(describing: ids))")
                            }
                            if let compiled = list {
                                observer.onNext(compiled)
                                observer.onCompleted()
                            } else {
                                observer.onError(ABPWKRuleStoreError.invalidData)
                            }
                        }
                    return Disposables.create()
                }
            }
    }
}
