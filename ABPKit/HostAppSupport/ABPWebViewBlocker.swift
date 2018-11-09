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
    var model: FilterList! { get }
    var webView: WKWebView! { get }
}

@available(iOS 11.0, macOS 10.13, *)
public
class ABPWebViewBlocker {
    var bag: DisposeBag!
    var ctrl: WKUserContentController!
    var pstr: Persistor!
    var ruleListID: String?
    var wkcb: WebKitContentBlocker!
    weak var host: ABPBlockable!

    public
    init(host: ABPBlockable) {
        bag = DisposeBag()
        self.host = host
        wkcb = WebKitContentBlocker()
        pstr = Persistor()
        ctrl = host.webView.configuration.userContentController
    }

    deinit {
        bag = nil
    }

    public
    func makeTestModel(blockList: BundledBlockList) -> FilterList {
        var list = FilterList()
        list.name = UUID().uuidString
        list.fileName = blockList.rawValue
        return list
    }

    public
    func loadURLString(_ urlString: String,
                       completion: (URL?, Error?) -> Void) {
        let newString = urlString.addingWebProtocol()
        if let url = URL(string: newString) {
            let request = URLRequest(url: url)
            host.webView.load(request)
            completion(url, nil)
        } else {
            completion(nil, ABPWebViewBlockerError.badURL)
        }
    }

    /// Clear and add rules for the host's model.
    public
    func addRules(completion: @escaping ([Error]?) -> Void) {
        var errors = [Error]()
        do {
            let result = try pstr.saveFilterListModel(host.model)
            try pstr.logRulesFiles()
            assert(result == true)
        } catch let err {
            errors.append(err)
        }
        wkcb.clearedRulesAll()
            .flatMap { errs -> Observable<WKContentRuleList> in
                if errs.count > 0 {
                    errors.append(ABPWKRuleStoreError.ruleListErrors(errorDictionary: errs))
                }
                return self.wkcb.addedWKStoreRules(addList: self.host.model)
            }
            .subscribe(onNext: { list in
                self.ruleListID = list.identifier
                self.wkcb.rulesStore
                    .lookUpContentRuleList(forIdentifier: self.ruleListID) { list, err in
                        if err != nil {
                            errors.append(err!)
                        }
                        if list != nil {
                            self.ctrl.add(list!)
                        } else {
                            errors.append(ABPWKRuleStoreError.missingRules)
                        }
                    }
            }, onError: { err in
                errors.append(err)
                completion(errors)
            }, onCompleted: {
                if errors.count == 0 {
                    log("Error count = \(errors.count)")
                    completion(nil)
                } else {
                    completion(errors)
                }
            }).disposed(by: bag)
    }
}
