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

// FilterList implementations will eventually be removed.

@available(iOS 11.0, macOS 10.13, *)
extension WebKitContentBlocker {
    /// FilterList implementation:
    func concatenatedRules(model: FilterList) -> Observable<(String, Int)> {
        do {
            let url = bundle != nil ? try model.rulesURL(bundle: bundle!) : try model.rulesURL()
            return try concatenatedRules()(RulesHelper().validatedRules()(url))
        } catch let err { return Observable.error(err) }
    }

    /// Handles blocklist rules for a user. User white list rule is added here
    /// because "ignore-previous-rules" seems to only apply within the context
    /// of the same rule list.
    func concatenatedRules(user: User,
                           customBundle: Bundle? = nil) -> RuleStringAndCount {
        let rhlp = RulesHelper(customBundle: customBundle) // only uses bundle if overridden
        let withWL: (User) throws -> RuleStringAndCount = {
            try self.concatenatedRules(customBundle: customBundle)(rhlp.validatedRules()(rhlp.rulesForUser()($0))
                .concat(self.whiteListRuleForUser()($0)))
        }
        let withoutWL: (User) throws -> RuleStringAndCount = {
            try self.concatenatedRules(customBundle: customBundle)(rhlp.validatedRules()(rhlp.rulesForUser()($0)))
        }
        do {
            if user.whitelistedDomains?.count ?? 0 > 0 {
                return try withWL(user)
            } else {
                return try withoutWL(user)
            }
        } catch let err { return Observable.error(err) }
    }

    /// Embedding a subscription inside this Observable has yielded the fastest performance for
    /// concatenating rules.
    /// Other methods tried:
    /// 1. flatMap + string append - ~4x slower
    /// 2. reduce - ~10x slower
    /// Returns blocklist string + rules count.
    func concatenatedRules(customBundle: Bundle? = nil) -> (Observable<BlockingRule>) -> Observable<(String, Int)> {
        return { obsRules in
            let rhlp = RulesHelper(customBundle: customBundle) // only uses bundle if overridden
            let encoder = JSONEncoder()
            var all = Constants.blocklistArrayStart
            var cnt = 0
            return Observable.create { observer in
                obsRules
                    .subscribe(onNext: { rule in
                        do {
                            cnt += 1
                            try all += rhlp.ruleToStringWithEncoder(encoder)(rule) + Constants.blocklistRuleSeparator
                        } catch let err { observer.onError(err) }
                    }, onCompleted: {
                        observer.onNext((all.dropLast() + Constants.blocklistArrayEnd, cnt))
                        observer.onCompleted()
                    }).disposed(by: self.bag)
                return Disposables.create()
            }
        }
    }

    /// FilterList implementation:
    /// Clear one or more matching rule lists associated with a filter list model.
    func ruleListClearersForModel() -> (FilterList) -> Observable<String> {
        return { model in
            return self.ruleIdentifiers()
                .flatMap { identifiers -> Observable<String> in
                    guard let ids = identifiers else { return Observable.error(ABPWKRuleStoreError.invalidData) }
                    let obs = ids
                        .filter { $0 == model.name }
                        .map { self.ruleListClearer()($0) }
                    if obs.count < 1 { return Observable.error(ABPWKRuleStoreError.missingRuleList) }
                    return Observable.concat(obs)
                }
        }
    }

    /// Return clearers for rules in the rule store for a user.
    func ruleListClearersForUser() -> (User) -> Observable<String> {
        return { user in
            return self.ruleIdentifiers()
                .flatMap { identifiers -> Observable<String> in
                    guard let hist = user.blockListHistory,
                          let ids = identifiers else { return Observable.error(ABPWKRuleStoreError.invalidData) }
                    let obs = ids
                        .filter { idr in !(hist.contains { $0.name == idr }) }
                        .map { idr in self.ruleListClearer()(idr) }
                    if obs.count < 1 { return Observable.error(ABPWKRuleStoreError.missingRuleList) }
                    return Observable.concat(obs)
                }
        }
    }

    /// Return clearers for all RLs.
    func ruleListAllClearers() -> Observable<String> {
        return ruleIdentifiers()
            .flatMap { identifiers -> Observable<String> in
                guard let ids = identifiers else { return Observable.error(ABPWKRuleStoreError.invalidData) }
                return Observable.concat(ids.map { self.ruleListClearer()($0) })
            }
    }

    /// Return clearer for an RL.
    func ruleListClearer() -> (String) -> Observable<String> {
        return { idr in
            return Observable.create { observer in
                self.rulesStore.removeContentRuleList(forIdentifier: idr) { err in
                    if err != nil { observer.onError(err!) }
                    observer.onNext(idr)
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
    }
}
