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
    public var bundle: Bundle?
    public var rulesStore: WKContentRuleListStore!

    public
    init?() {
        bag = DisposeBag()
        guard let rulesStore = try? WKContentRuleListStore(url: cfg.rulesStoreIdentifier()),
              let uwRulesStore = rulesStore
        else {
            return nil
        }
        self.rulesStore = uwRulesStore
    }

    /// Returns an observable after adding.
    public
    func addedWKStoreRules(addList: FilterList) -> Observable<WKContentRuleList> {
        return concatenatedRules(model: addList)
            .flatMap { result -> Observable<WKContentRuleList> in
                return Observable.create { observer in
                    self.rulesStore
                        .compileContentRuleList(forIdentifier: addList.name,
                                                encodedContentRuleList: result.0) { list, err in
                            guard err == nil else {
                                observer.onError(err!)
                                return
                            }
                            self.rulesStore.getAvailableContentRuleListIdentifiers({ (ids: [String]?) in
                                if let name = addList.name,
                                   let uwIDs = ids,
                                   !uwIDs.contains(name) {
                                    observer.onError(ABPWKRuleStoreError.missingRuleList)
                                }
                                ABPKit.log("📙 \(String(describing: ids))")
                            })
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
