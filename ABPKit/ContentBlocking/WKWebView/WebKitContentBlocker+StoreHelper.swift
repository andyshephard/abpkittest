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

@available(iOSApplicationExtension 11.0, OSXApplicationExtension 10.13, *)
extension WebKitContentBlocker {
    /// Embedding a subscription inside this Observable has yielded the fastest performance for
    /// concatenating rules.
    /// Other methods tried:
    /// 1. flatMap + string append - ~4x slower
    /// 2. reduce - ~10x slower
    func concatenatedRules(model: FilterList) -> Observable<(String, Int)> {
        let sep = ","
        let arrStart = "["
        let arrEnd = "]"
        guard let rulesURL = try? model.rulesURL(),
              let url = rulesURL
        else {
            return Observable.error(ABPWKRuleStoreError.missingRules)
        }
        let encoder = JSONEncoder()
        var first = true
        var all = arrStart
        let rhlpr = RulesHelper()
        var cnt = 0
        return Observable.create { observer in
            rhlpr.validatedRules(for: url)
                .subscribe(onNext: { rule in
                    guard let data = try? encoder.encode(rule),
                          let rule = String(data: data,
                                            encoding: .utf8)
                    else {
                        observer.onError(ABPFilterListError.invalidData)
                        return
                    }
                    cnt += 1
                    if first {
                        all += rule; first = false
                    } else {
                        all += sep + rule
                    }
                },
                onCompleted: {
                    observer.onNext((all + arrEnd, cnt))
                    observer.onCompleted()
                }).disposed(by: self.bag)
            return Disposables.create()
        }
    }

    /// Clear all rules in the WKRuleListStore.
    func clearRules(completion: @escaping (NamedErrors) -> Void) {
        var errors = NamedErrors()
        rulesStore
            .getAvailableContentRuleListIdentifiers { identifiers in
                guard let ids = identifiers else {
                    return
                }
                ids.forEach { identifier in
                    self.rulesStore
                        .removeContentRuleList(forIdentifier: identifier) { err in
                            errors[identifier] = err
                        }
                    completion(errors)
                }
            }
    }

    /// Clear all compiled rule lists.
    func clearedRulesAll() -> Observable<NamedErrors> {
        return clearedRules(clearAll: true)
    }

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
}
