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

// swiftlint:disable type_body_length
@available(OSX 10.13, *)
class WebKitContentBlockingTests: XCTestCase {
    let maxRules = 50000
    let testRulesCount = 21475
    let testRulesCountUserFakeExceptions = 7
    let testRulesCountUserTestEasylist = 21475
    let timeout: TimeInterval = 20
    var bag: DisposeBag!
    var cfg: Config!
    var pstr: Persistor!
    var tfutil: TestingFileUtility!
    var wkcb: WebKitContentBlocker!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        cfg = Config()
        if let uwrp = try? Persistor() { pstr = uwrp } else { XCTFail("Persistor failed init.") }
        tfutil = TestingFileUtility()
        wkcb = WebKitContentBlocker()
        let clearModels = {
            do { try self.pstr.clearFilterListModels() } catch let err { XCTFail("Error clearing models: \(err)") }
        }
        let unlock = BehaviorRelay<Bool>(value: false)
        wkcb.ruleListAllClearers()
            .subscribe(onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                clearModels()
                unlock.accept(true)
            }).disposed(by: bag)
        let waitDone = try? unlock.asObservable()
            .skip(1)
            .toBlocking(timeout: timeout / 4)
            .first()
        XCTAssert(waitDone == true,
                  "Failed to clear rules.")
    }

    func testClearRulesForUser() throws {
        let expect = expectation(description: #function)
        var user = try User()
        user.blockList = try BlockList(withAcceptableAds: true, source: BundledTestingBlockList.fakeExceptions)
        guard let lst = user.blockList else { XCTFail("Bad BL"); return }
        addNewRules(arg: user, name: lst.name) { idr in
            self.wkcb.ruleListClearersForUser()(user)
                .subscribe(onNext: { removed in
                    XCTAssert(removed == idr,
                              "Bad name.")
                }, onError: { err in
                    XCTFail("Error: \(err)")
                }, onCompleted: {
                    expect.fulfill()
                }).disposed(by: self.bag)
        }
        wait(for: [expect], timeout: timeout)
    }

    /// Config test.
    func testAppGroupMac() throws {
        let name = try cfg.defaultsSuiteName()
        let dflts = UserDefaults(suiteName: name)
        XCTAssert(dflts != nil,
                  "Missing user defaults.")
    }

    /// Config test.
    func testContainerURL() {
        let url = try? cfg.containerURL()
        XCTAssert(url != nil,
                  "Missing container URL.")
    }

    /// Negative test for adding a model filter list with missing rules.
    /// Specific error ABPFilterListError.notFound is expected. This was updated
    /// after errors were being reported for attempting to delete bundled
    /// resources. It wasn't an error condition before Xcode 10.1, apparently.
    func testListWithoutRules() throws {
        let expect = expectation(description: #function)
        var list = try FilterList()
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
        wait(for: [expect], timeout: timeout / 4)
    }

    /// This test was previously failing occasionally due to a possible race
    /// condition with setUp(). The problem should be fixed in
    /// https://gitlab.com/eyeo/auxiliary/track/issues/230.
    func testRuleListIDs() {
        let expect = expectation(description: #function)
        let start = Date()
        self.wkcb.rulesStore
            .getAvailableContentRuleListIdentifiers { ids in
                XCTAssert(ids?.count == 0,
                          "Failed to get IDs.")
                let end = fabs(start.timeIntervalSinceNow)
                log("get ids ⏱️ \(end)")
                expect.fulfill()
            }
        wait(for: [expect], timeout: timeout / 4)
    }

    /// Rules handling through ABPKit with a final clear.
    func testLocalBlocklistAddToWKStore1() {
        let mdlr = FilterListTestModeler()
        mdlr.testBundleFilename = "test-easylist_content_blocker.json"
        let expect = expectation(description: #function)
        do {
            try pstr.clearRulesFiles()
            let list = try mdlr.makeLocalFilterList(bundledRules: false)
            try pstr.saveFilterListModel(list)
            wkcb.addedWKStoreRules(addList: list)
                .flatMap { _ -> Observable<String> in
                    let models = try? self.pstr.loadFilterListModels()
                    XCTAssert(models?.count == 1,
                              "Bad models count.")
                    return self.wkcb.ruleListClearersForModel()(list)
                }
                .subscribe(onNext: { removed in
                    XCTAssert(removed == list.name,
                              "Name does not match.")
                }, onError: { err in
                    XCTFail("Got error: \(err)")
                }, onCompleted: {
                    self.logRules()
                    expect.fulfill()
                }).disposed(by: bag)
        } catch let err { XCTFail("Error: \(err)") }
        wait(for: [expect], timeout: timeout)
    }

    /// Test compiling rules with the default callback of compileRules.
    func testLocalBlocklistAddToWKStore2() {
        let expect = expectation(description: #function)
        do {
            try pstr.clearRulesFiles()
            let list = try FilterListTestModeler().makeLocalFilterList(bundledRules: false)
            try pstr.saveFilterListModel(list)
            try pstr.logRulesFiles()
            addNewRules(arg: list, name: list.name) { _ in expect.fulfill() }
        } catch let err { XCTFail("🚨 Error during add: \(err)") }
        wait(for: [expect], timeout: timeout)
    }

    /// Add rules to WK store for user.
    func testAddToWKStoreForUser() {
        let expect = expectation(description: #function)
        do {
            try pstr.clearRulesFiles()
            var user = try User()
            user.blockList = try BlockList(withAcceptableAds: true, source: BundledTestingBlockList.fakeExceptions)
            try pstr.logRulesFiles()
            addNewRules(arg: user, name: user.blockList!.name) { _ in expect.fulfill() }
        } catch let err { XCTFail("🚨 Error during add: \(err)") }
        wait(for: [expect], timeout: timeout)
    }

    func testGetStoredRules() throws {
        let expect = expectation(description: #function)
        do {
            try pstr.clearRulesFiles()
            var user1 = try User()
            let blst1 = try BlockList(withAcceptableAds: true, source: BundledTestingBlockList.fakeExceptions)
            user1.blockList = blst1
            var user2 = try User()
            let blst2 = try BlockList(withAcceptableAds: false, source: BundledTestingBlockList.testingEasylist)
            user2.blockList = blst2
            try pstr.logRulesFiles()
            guard let lst1 = user1.blockList, let lst2 = user2.blockList else { XCTFail("Bad BL"); return }
            addNewRules(arg: user1, name: lst1.name) { _ in
                self.addNewRules(arg: user2, name: lst2.name) { _ in
                    self.wkcb.rulesStore.getAvailableContentRuleListIdentifiers { ids in
                        XCTAssert(ids?.count == 2,
                                  "Bad add.")
                        self.ruleList(name: lst1.name)
                            .flatMap { list -> Observable<WKContentRuleList> in
                                XCTAssert(list.identifier == lst1.name,
                                          "Bad name 1.")
                                return self.ruleList(name: lst2.name)
                            }
                            .subscribe(onNext: { list in
                                XCTAssert(list.identifier == lst2.name,
                                          "Bad name 2.")
                            }, onError: { err in
                                XCTFail("Error: \(err)")
                            }, onCompleted: {
                                expect.fulfill()
                            }).disposed(by: self.bag)
                    }
                }
            }
        } catch let err { XCTFail("🚨 Error during add: \(err)") }
        wait(for: [expect], timeout: timeout)
    }

    private
    enum ConcatType: String {
        case user
        case filterList
    }

    private
    func concat<T>(_ type: ConcatType, arg: T) -> Observable<(String, Int)> {
        switch type {
        case .user:
            if let user = arg as? User {
                return wkcb.concatenatedRules(user: user, customBundle: Bundle(for: WebKitContentBlockingTests.self))
            }
        case .filterList:
            if let list = arg as? FilterList {
                return wkcb.concatenatedRules(model: list)
            }
        }
        return Observable.empty()
    }

    private
    func concatCount<T>(_ type: ConcatType, arg: T) -> Int {
        switch type {
        case .user:
            let user = arg as? User
            if let usr = user, let lst = usr.blockList {
                switch lst.source {
                case BundledTestingBlockList.fakeExceptions:
                    return testRulesCountUserFakeExceptions
                case BundledTestingBlockList.testingEasylist:
                    return testRulesCountUserTestEasylist
                default:
                    break
                }
            }
        case .filterList:
            return testRulesCount
        }
        return -1
    }

    private
    func addNewRules<T>(arg: T, name: String, completion: @escaping (String) -> Void) {
        var type: ConcatType!
        switch T.self {
        case let typ where typ == User.self:
            type = .user
        case let typ where typ == FilterList.self:
            type = .filterList
        default:
            XCTFail("Unknown type.")
        }
        let start = Date()
        concat(type, arg: arg)
            .flatMap { rules, cnt -> Observable<(WKContentRuleList?, Error?)> in
                let end1 = fabs(start.timeIntervalSinceNow)
                log("cat rules ⏱️1 \(end1)")
                let expectCnt = self.concatCount(type, arg: arg)
                XCTAssert(expectCnt == cnt,
                          "Bad rules count: Expected \(expectCnt) but got \(cnt)).")
                return self.rulesCompiled(name: name, rules: rules)
            }
            .subscribe(onNext: { _ in
                let end2 = fabs(start.timeIntervalSinceNow)
                log("add rules ⏱️2 \(end2)")
                completion(name)
            }, onError: { err in
                XCTFail("🚨 Error during processing rules: \(err)")
            }).disposed(by: bag)
    }

    /// This private function serves to cover cases not involving a User as
    /// required by the alternate FilterList-based processing that will be
    /// eventually removed.
    private
    func rulesCompiled(name: String, rules: String) -> Observable<(WKContentRuleList?, Error?)> {
        guard let store = wkcb?.rulesStore else { XCTFail("Bad store."); return Observable.empty() }
        return Observable.create { observer in
            DispatchQueue.main.async { // compileContentRuleList requires main
                store
                    .compileContentRuleList(forIdentifier: name,
                                            encodedContentRuleList: rules) { list, err in
                        if err != nil { XCTFail("Error: \(err as Error?)") }
                        observer.onNext((list, err))
                        observer.onCompleted()
                    }
            }
            return Disposables.create()
        }
    }

    private
    func ruleList(name: String) -> Observable<WKContentRuleList> {
        guard let store = wkcb?.rulesStore else { XCTFail("Bad store."); return Observable.empty() }
        return Observable.create { observer in
            store
                .lookUpContentRuleList(forIdentifier: name) { list, err in
                    if err != nil { XCTFail("Error: \(err as Error?)") }
                    if list != nil { observer.onNext(list!) }
                    observer.onCompleted()
                }
            return Disposables.create()
        }
    }

    private
    func logRules() {
        wkcb?.rulesStore
            .getAvailableContentRuleListIdentifiers { (ids: [String]?) in
                log("📙 \(ids as [String]?)")
            }
    }
}
