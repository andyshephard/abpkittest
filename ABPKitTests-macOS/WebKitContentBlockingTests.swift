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

@testable import ABPKit

import RxBlocking
import RxCocoa
import RxSwift
import SafariServices
import WebKit
import XCTest

@available(OSX 10.13, *)
class WebKitContentBlockingTests: XCTestCase {
    let maxRules = 50000
    let testRulesCount = 45899
    let timeout: TimeInterval = 20
    var bag: DisposeBag!
    var cfg: Config!
    var tfutil: TestingFileUtility!
    var pstr: Persistor!
    var wkcb: WebKitContentBlocker!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        cfg = Config()
        pstr = Persistor()
        tfutil = TestingFileUtility()
        wkcb = WebKitContentBlocker()
        let clearModels = {
            do { try self.pstr.clearFilterListModels() } catch let err { XCTFail("Error clearing models: \(err)") }
        }
        let start = Date()
        let unlock = BehaviorRelay<Bool>(value: false)
        wkcb.clearedRulesAll()
            .subscribe(onNext: { errDict in
                if errDict.count > 0 {
                    XCTFail("Error clearing store rules: \(errDict)")
                }
                clearModels()
            }, onError: {err in
                XCTFail("🚨 Error during clear: \(err)")
            }, onCompleted: {
                unlock.accept(true)
            }, onDisposed: {
                let end = fabs(start.timeIntervalSinceNow)
                ABPKit.log("⏱️ \(end)")
            }).disposed(by: self.bag)
        let waitDone = try? unlock.asObservable()
            .skip(1)
            .toBlocking(timeout: timeout / 4)
            .first()
        XCTAssert(waitDone == true,
                  "Failed to clear rules.")
    }

    func testAppGroupMac() {
        guard let name = try? cfg.defaultsSuiteName() else {
            XCTFail("Bad suite name.")
            return
        }
        let dflts = UserDefaults(suiteName: name)
        XCTAssert(dflts != nil,
                  "Missing user defaults.")
    }

    func testContainerURL() {
        let url = try? cfg.containerURL()
        XCTAssert(url != nil,
                  "Missing container URL.")
    }

    /// Negative test for adding a model filter list with missing rules.
    /// Specific error ABPFilterListError.notFound is expected. This was updated
    /// after errors were being reported for attempting to delete bundled
    /// resources. It wasn't an error condition before Xcode 10.1, apparently.
    func testListWithoutRules() {
        let expect = expectation(description: #function)
        var list = FilterList()
        list.name = "test"
        // List has no filename.
        try? pstr.logRulesFiles()
        wkcb.addedWKStoreRules(addList: list)
            .subscribe(onError: { err in
                switch err {
                case ABPFilterListError.notFound:
                    expect.fulfill()
                default:
                    XCTFail("🚨 Error during add: \(err)")
                }
            }, onCompleted: {
                XCTFail("Unexpected completion.")
            }).disposed(by: bag)
        wait(for: [expect],
             timeout: timeout / 4)
    }

    func testRuleListIDs() {
        let expect = expectation(description: #function)
        let start = Date()
        self.wkcb.rulesStore
            .getAvailableContentRuleListIdentifiers { ids in
                XCTAssert(ids?.count == 0,
                          "Failed to get IDs.")
                let end = fabs(start.timeIntervalSinceNow)
                ABPKit.log("⏱️ \(end)")
                expect.fulfill()
            }
        wait(for: [expect],
             timeout: timeout / 4)
    }

    /// Rules handling through ABPKit with a final clear.
    func testLocalBlocklistAddToWKStore1() {
        let mdlr = FilterListTestModeler()
        mdlr.testBundleFilename = "test-easylist-42perc.json"
        let expect = expectation(description: #function)
        do {
            try pstr.clearRulesFiles()
            let list = try mdlr.makeLocalBlockList(bundledRules: false)
            let saveResult = try pstr.saveFilterListModel(list)
            XCTAssert(saveResult == true,
                      "Failed save.")
            wkcb.addedWKStoreRules(addList: list)
                .flatMap { _ -> Observable<NamedErrors> in
                    let models = try? self.pstr.loadFilterListModels()
                    XCTAssert(models?.count == 1,
                              "Bad models count.")
                    return self.wkcb.clearedRules(model: list)
                }
                .subscribe(onNext: { errDict in
                    XCTAssert(errDict.count == 0,
                              "Nonzero errors in \(errDict)")
                }, onError: { err in
                    XCTFail("Got error: \(err)")
                }, onCompleted: {
                    self.logRules()
                    expect.fulfill()
                }).disposed(by: bag)
        } catch let err {
            XCTFail("Error: \(err)")
        }
        wait(for: [expect],
             timeout: timeout)
    }

    /// Test compiling rules with the default callback.
    func testLocalBlocklistAddToWKStore2() {
        let expect = expectation(description: #function)
        let mdlr = FilterListTestModeler()
        do {
            try pstr.clearRulesFiles()
            let list = try mdlr.makeLocalBlockList(bundledRules: false)
            guard let listName = list.name else {
                XCTFail("Missing name.")
                return
            }
            let saveResult = try pstr.saveFilterListModel(list)
            XCTAssert(saveResult == true, "Failed save.")
            try pstr.logRulesFiles()
            let start = Date()
            wkcb.concatenatedRules(model: list)
                .subscribe(onNext: { result in
                    let end1 = fabs(start.timeIntervalSinceNow)
                    ABPKit.log("⏱️1 \(end1)")
                    XCTAssert(self.testRulesCount == result.1,
                              "Rule count is wrong.")
                    self.compileRules(storeName: listName,
                                      rules: result.0,
                                      completion: { _, err in
                        guard err == nil else {
                            XCTFail("Failed compile with error: \(err!)")
                            expect.fulfill()
                            return
                        }
                        let end2 = fabs(start.timeIntervalSinceNow)
                        ABPKit.log("⏱️2 \(end2)")
                        expect.fulfill()
                    })
                }, onError: { err in
                    XCTFail("🚨 Error during processing rules: \(err)")
                }).disposed(by: bag)
        } catch let err {
            XCTFail("🚨 Error during add: \(err)")
        }
        wait(for: [expect],
             timeout: timeout)
    }

    private
    func compileRules(storeName: String,
                      rules: String,
                      completion: @escaping (WKContentRuleList?, Error?) -> Void) {
        wkcb?.rulesStore
            .compileContentRuleList(forIdentifier: storeName,
                                    encodedContentRuleList: rules) { list, err in
                completion(list, err)
            }
    }

    private
    func logRules() {
        wkcb?.rulesStore.getAvailableContentRuleListIdentifiers({ (ids: [String]?) in
            ABPKit.log("📙 \(String(describing: ids))")
        })
    }
}
