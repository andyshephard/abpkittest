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
class WebKitContentBlocker: Loggable {
    typealias LogType = [String]?
    typealias RuleStringAndCount = Observable<(String, Int)>

    let cfg = Config()
    var bag: DisposeBag!
    var bundle: Bundle?
    var rulesStore: WKContentRuleListStore!
    /// For debugging.
    var logWith: ((LogType) -> Void)?

    init?(logWith: ((LogType) -> Void)? = nil) {
        bag = DisposeBag()
        guard let rulesStore = (try? WKContentRuleListStore(url: cfg.rulesStoreIdentifier()))
            as? WKContentRuleListStore else { return nil }
        self.rulesStore = rulesStore
        self.logWith = logWith
    }

    /// From user's block list, make a rule list and it to the store.
    func rulesAddedWKStore(user: User) -> Observable<WKContentRuleList> {
        return concatenatedRules(user: user)
            .flatMap { result -> Observable<WKContentRuleList> in
                return self.rulesCompiled(user: user, rules: result.0)
            }
            .flatMap { rlst -> Observable<WKContentRuleList> in
                return self.ruleListVerified(userList: user.blockList, ruleList: rlst)
            }
    }

    func whiteListRuleForUser() -> (User) -> Observable<BlockingRule> {
        return { user in
            guard let dmns = user.whitelistedDomains, dmns.count > 0 else { return Observable.error(ABPUserModelError.badDataUser) }
            let userWLRule: (User) -> Observable<BlockingRule> = { user in
                var cbUtil: ContentBlockerUtility!
                do {
                    cbUtil = try ContentBlockerUtility()
                } catch let err { return Observable.error(err) }
                return Observable.just(cbUtil.whiteListRuleForDomains()(dmns))
            }
            return userWLRule(user)
        }
    }

    /// IDs may be logged using withIDs.
    func ruleListVerified<U: BlockListable>(userList: U?, ruleList: WKContentRuleList) -> Observable<WKContentRuleList> {
        return ruleIdentifiers()
            .flatMap { ids -> Observable<WKContentRuleList> in
                return Observable.create { observer in
                    if let ulst = userList,
                       ulst.name != ruleList.identifier ||
                       ids?.contains(ulst.name) == false { observer.onError(ABPWKRuleStoreError.invalidData) }
                    self.logWith?(ids)
                    observer.onNext(ruleList)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }

    /// Wrapper for IDs.
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
        return rulesCompiledForIdentifier(user.blockList?.name)(rules)
    }

    func rulesCompiledForIdentifier(_ identifier: String?) -> (String) -> Observable<WKContentRuleList> {
        return { rules in
            return Observable.create { observer in
                self.rulesStore
                    .compileContentRuleList(forIdentifier: identifier,
                                            encodedContentRuleList: rules) { list, err in
                        guard err == nil else { observer.onError(err!); return }
                        if list != nil {
                            observer.onNext(list!)
                            observer.onCompleted()
                        } else { observer.onError(ABPWKRuleStoreError.invalidData) }
                    }
                return Disposables.create()
            }
        }
    }

    /// Remove rule lists from store that are not in user state. Correct state is
    /// rule store is less than or equal to user history.
    func syncHistoryRemovers(user: User) -> Observable<Observable<String>> {
        var all: [String]!
        do {
            all = try names()(user.blockListHistory) + names()(user.downloads)
        } catch let err { return Observable.error(err) }
        return ruleIdentifiers()
            .flatMap { ids -> Observable<Observable<String>> in
                return Observable.create { observer in
                    // Add remove if identifier in store is not in the user's history.
                    let observables = ids?.filter { idr in !all.contains { $0 == idr } }
                        .map { return self.listRemovedFromStore(identifier: $0) }
                        .reduce([]) { $0 + [$1] }
                    // Empty string sent to keep operation chains continuous:
                    if let obs = observables, obs.count > 0 {
                        observer.onNext(Observable.concat(obs))
                    } else { observer.onNext(Observable.just("")) }
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }

    /// Additional withID closure for debugging as found useful during testing.
    func listRemovedFromStore(identifier: String, withID: ((String) -> Void)? = nil) -> Observable<String> {
        return Observable.create { observer in
            self.rulesStore
                .removeContentRuleList(forIdentifier: identifier) { err in
                    withID?(identifier)
                    // Remove for identifier complete now.
                    if err != nil { observer.onError(err!) }
                    observer.onNext(identifier)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }

    /// Based on FilterList. Returns an observable after adding. This function
    /// is now only for reference and testing. The User model should be
    /// preferred over FilterList. IDs may be logged using withIDs.
    func addedWKStoreRules(addList: FilterList) -> Observable<WKContentRuleList> {
        return concatenatedRules(model: addList)
            .flatMap { result -> Observable<WKContentRuleList> in
                return Observable.create { observer in
                    self.rulesStore
                        .compileContentRuleList(forIdentifier: addList.name,
                                                encodedContentRuleList: result.0) { list, err in
                            guard err == nil else { observer.onError(err!); return }
                            self.rulesStore.getAvailableContentRuleListIdentifiers { (ids: [String]?) in
                                if ids?.contains(addList.name) == false { observer.onError(ABPWKRuleStoreError.missingRuleList) }
                                self.logWith?(ids)
                            }
                            if let compiled = list {
                                observer.onNext(compiled)
                                observer.onCompleted()
                            } else { observer.onError(ABPWKRuleStoreError.invalidData) }
                        }
                    return Disposables.create()
                }
            }
    }

    private
    func names<U: BlockListable>() -> ([U]?) throws -> [String] {
        return {
            guard let models = $0 else { throw ABPUserModelError.badDataUser }
            return models.map { $0.name }.reduce([]) { $0 + [$1] }
        }
    }
}
