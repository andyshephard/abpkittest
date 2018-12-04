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

/// FilterList implementations will eventually be removed.

@available(iOS 11.0, macOS 10.13, *)
extension WebKitContentBlocker {
    /// FilterList implementation:
    /// Embedding a subscription inside this Observable has yielded the fastest performance for
    /// concatenating rules.
    /// Other methods tried:
    /// 1. flatMap + string append - ~4x slower
    /// 2. reduce - ~10x slower
    /// Returns blocklist string + rules count.
    func concatenatedRules(model: FilterList) -> Observable<(String, Int)> {
        var rulesURL: URL?
        do {
            if bundle != nil {
                rulesURL = try model.rulesURL(bundle: bundle!)
            } else {
                rulesURL = try model.rulesURL()
            }
        } catch let err {
            return Observable.error(err)
        }
        guard let url = rulesURL else {
            return Observable.error(ABPWKRuleStoreError.missingRules)
        }
        let encoder = JSONEncoder()
        var first = true
        var all = Constants.blocklistArrayStart
        var cnt = 0
        return Observable.create { observer in
            RulesHelper()
                .validatedRules()(url)
                .subscribe(onNext: { rule in
                    let rstr = self.ruleString(rule: rule, encoder: encoder)
                    if rstr == nil { observer.onError(ABPFilterListError.invalidData) }
                    cnt += 1
                    if !first {
                        all += Constants.blocklistRuleSeparator + rstr!
                    } else { all += rstr!; first = false }
                },
                onCompleted: {
                    observer.onNext((all + Constants.blocklistArrayEnd, cnt))
                    observer.onCompleted()
                }).disposed(by: self.bag)
            return Disposables.create()
        }
    }

    /// Embedding a subscription inside this Observable has yielded the fastest performance for
    /// concatenating rules.
    /// Other methods tried:
    /// 1. flatMap + string append - ~4x slower
    /// 2. reduce - ~10x slower
    /// Returns blocklist string + rules count.
    func concatenatedRules(user: User,
                           customBundle: Bundle? = nil) -> Observable<(String, Int)> {
        let rhlp = RulesHelper()
        rhlp.useBundle = customBundle // only uses bundle if overridden
        guard let url = try? rhlp.rulesForUser()(user) else {
            return Observable.error(ABPWKRuleStoreError.missingRules)
        }
        let encoder = JSONEncoder()
        var first = true
        var all = Constants.blocklistArrayStart
        var cnt = 0
        return Observable.create { observer in
            rhlp.validatedRules()(url)
                .subscribe(onNext: { rule in
                    let rstr = self.ruleString(rule: rule, encoder: encoder)
                    if rstr == nil { observer.onError(ABPFilterListError.invalidData) }
                    cnt += 1
                    if !first {
                        all += Constants.blocklistRuleSeparator + rstr!
                    } else { all += rstr!; first = false }
                }, onCompleted: {
                    observer.onNext((all + Constants.blocklistArrayEnd, cnt))
                    observer.onCompleted()
                }).disposed(by: self.bag)
            return Disposables.create()
        }
    }

    /// Clear all compiled rule lists.
    /// Only for testing while FilterList usage is being transitioned to User + BlockList.
    func clearedRulesAll() -> Observable<NamedErrors> {
        return clearedRules(clearAll: true)
    }

    /// FilterList implementation:
    /// Clear an individual rule list associated with a filter list model.
    func clearedRules(model: FilterList? = nil,
                      clearAll: Bool = false) -> Observable<NamedErrors> {
        var name: FilterListName?
        if model != nil {
            name = model?.name
        } else {
            if !clearAll {
                return Observable.just(NamedErrors())
            }
        }
        return Observable.create { observer in
            var errors = NamedErrors()
            self.rulesStore
                .getAvailableContentRuleListIdentifiers { identifiers in
                    guard let ids = identifiers else {
                        observer.onError(ABPWKRuleStoreError.invalidData)
                        return
                    }
                    ids.forEach { identifier in
                        if (name != nil && identifier == name!) || clearAll {
                            self.rulesStore
                                .removeContentRuleList(forIdentifier: identifier) { err in
                                    errors[identifier] = err
                                }
                        }
                    }
                    observer.onNext(errors)
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }

    /// Clear rules in rule store for a user.
    func clearedRules(user: User,
                      clearAll: Bool = false) -> Observable<NamedErrors> {
        guard let hist = user.blockListHistory else {
            return Observable.error(ABPWKRuleStoreError.invalidData)
        }
        return ruleIdentifiers()
            .flatMap { ids -> Observable<NamedErrors> in
                return Observable.create { observer in
                    guard let uwIDs = ids else {
                        observer.onError(ABPWKRuleStoreError.invalidData); return Disposables.create()
                    }
                    var errors = NamedErrors()
                    uwIDs.forEach { identifier in
                        if !(hist.contains { $0.name == identifier }) || clearAll {
                            self.rulesStore
                                .removeContentRuleList(forIdentifier: identifier) { err in
                                    errors[identifier] = err
                                }
                        }
                    }
                    observer.onNext(errors)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }

    private
    func ruleString(rule: BlockingRule, encoder: JSONEncoder) -> String? {
        guard let data = try? encoder.encode(rule),
              let rule = String(data: data, encoding: .utf8) else { return nil }
        return rule
    }
}
