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
import WebKit
import XCTest

/// Tests future user states.
class UserAfterWhiteListTests: XCTestCase {
    let testSource = RemoteBlockList.self
    let lastUser = UserUtility().lastUser
    let timeout: TimeInterval = 5
    var bag: DisposeBag!
    var user: User!
    var wkcb: WebKitContentBlocker!
    var expectedCount: Int?
    let domains: (_ expectedCount: inout Int) throws -> [String] = { expCnt in
        guard let arr = RandomStateUtility().randomState(for: [String].self) else {
            throw ABPKitTestingError.invalidData
        }
        expCnt = arr.count
        return arr
    }

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        do {
            try Persistor().clearRulesFiles()
            user = try UserUtility().aaUserNewSaved(testSource.easylistPlusExceptions)
        } catch let err { XCTFail("Error: \(err)") }
        wkcb = WebKitContentBlocker()
        let unlock = BehaviorRelay<Bool>(value: false)
        wkcb.clearedRulesAll()
            .subscribe(onNext: { errs in
                if errs.count > 0 { XCTFail("Error clearing store rules: \(errs)") }
            }, onError: { err in
                XCTFail("🚨 Error during clear: \(err)")
            }, onCompleted: {
                unlock.accept(true)
            }).disposed(by: self.bag)
        let waitDone = try? unlock.asObservable()
            .skip(1)
            .toBlocking(timeout: timeout / 2.0)
            .first()
        XCTAssert(waitDone == true,
                  "Failed to clear rules.")
    }

    func testEmptyWL() throws {
        user.whiteLists? += [WhiteList()]
        let saved = try user.saved()
        XCTAssert(lastUser(true)?.whiteLists?.first == saved.whiteLists?.first,
                  "Bad list.")
    }

    func testUpdateWLHistory() throws {
        user.whiteLists = Array(
            repeating: WhiteList(), count: Constants.userWhiteListMax + Int.random(in: 1...3))
        let saved = try user.updateWhiteLists().saved()
        XCTAssert(saved.whiteLists?.count == Constants.userWhiteListMax,
                  "Bad count of \(saved.whiteLists?.count as Int?).")
    }

    /// Test rules for single WL with sync attempt.
    func testRulesForWL() throws {
        let expect = expectation(description: #function)
        let wlst = WhiteList()
        let cbUtil = try ContentBlockerUtility()
        var expectedCount: Int = 0
        try wkcb.concatenatedRules()(Observable.from(
            domains(&expectedCount).map { cbUtil.whiteListRuleForDomain()($0) }
        ))
        .flatMap { result -> Observable<WKContentRuleList> in
            XCTAssert(result.1 == expectedCount,
                      "Bad count.")
            return self.wkcb.rulesCompiledForIdentifier(wlst.name)(result.0)
        }
        .flatMap { list -> Observable<[String]?> in
            XCTAssert(list.identifier == wlst.name,
                      "Bad name.")
            self.user.whiteLists? += [wlst]
            do {
                try self.user.save()
            } catch let err { XCTFail("Error: \(err)") }
            return self.wkcb.ruleIdentifiers()
        }
        .flatMap { ids -> Observable<Observable<String>> in
            guard let last = self.lastUser(true) else {
                XCTFail("Bad user."); return Observable.empty()
            }
            XCTAssert(last.whiteLists?.first?.name == ids?.first,
                      "Bad name.")
            return self.wkcb.syncHistoryRemovers(user: last)
        }
        .flatMap { remove -> Observable<String> in
            return remove
        }
        .flatMap { _ -> Observable<[String]?> in
            return self.wkcb.ruleIdentifiers()
        }
        .subscribe(onNext: { ids in
            XCTAssert(ids?.count == 1,
                      "Bad count.")
        }, onError: { err in
            XCTFail("Error: \(err)")
        }, onCompleted: {
            expect.fulfill()
        }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }

    func testWLMultiple() throws {
        let expect = expectation(description: #function)
        let iterMax = Constants.userWhiteListMax + Int.random(in: 1...3)
        Observable<Int>
            .interval(timeout, scheduler: MainScheduler.asyncInstance)
            .startWith(-1)
            .take(iterMax)
            .subscribe(onNext: {
                if let user = self.lastUser(true) {
                    self.addWLSubscription(expect, $0 + 2 == iterMax)(user).disposed(by: self.bag)
                } else { XCTFail("Bad user.") }
            }, onError: { err in
                XCTFail("Error: \(err)")
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout * Double(iterMax))
    }

    private
    func addWLtoUser(wlst: WhiteList = WhiteList()) -> (User) -> Observable<WKContentRuleList> {
        return { user in
            var expectedCount: Int = 0
            var cbUtil: ContentBlockerUtility!
            var dmns: [String]!
            do {
                cbUtil = try ContentBlockerUtility()
                dmns = try self.domains(&expectedCount)
            } catch let err { return Observable.error(err) }
            return self.wkcb.concatenatedRules()(Observable.from(
                dmns.map { cbUtil.whiteListRuleForDomain()($0) }
            ))
            .flatMap { result -> Observable<WKContentRuleList> in
                XCTAssert(result.1 == expectedCount,
                          "Bad count.")
                var copy = user
                copy.whiteLists? += [wlst]
                do {
                    try copy.save()
                } catch let err { return Observable.error(err) }
                return self.wkcb.rulesCompiledForIdentifier(wlst.name)(result.0)
            }
        }
    }

    private
    func addWLSubscription(_ expect: XCTestExpectation, _ shouldEnd: Bool) -> (User) -> Disposable {
        return { user in
            var saved: User?
            return self.addWLtoUser()(user)
                .flatMap { lst -> Observable<Observable<String>> in
                    do {
                        guard let last = self.lastUser(true) else { XCTFail("Bad user."); return Observable.empty() }
                        XCTAssert(last.whiteLists?.filter { $0.name == lst.identifier }.count == 1,
                                  "Bad count.")
                        saved = try last.updateWhiteLists().saved()
                        log("👩‍🎤WLs before sync #\(saved?.whiteLists?.count as Int?) - \(saved?.whiteLists as [WhiteList]?)")
                    } catch let err { return Observable.error(err) }
                    return self.wkcb.syncHistoryRemovers(user: saved!)
                }
                .flatMap { remove -> Observable<String> in
                    return remove
                }
                .flatMap { removed -> Observable<[String]?> in
                    XCTAssert(saved?.whiteLists?.filter { $0.name == removed }.count == 0,
                              "Bad remove.")
                    return self.wkcb.ruleIdentifiers()
                }
                .subscribe(onError: { err in
                    XCTFail("Error: \(err)")
                }, onCompleted: {
                    let last = self.lastUser(true)
                    log("👩‍🎤WLs after sync #\(last?.whiteLists?.count as Int?) - \(last?.whiteLists as [WhiteList]?)")
                    XCTAssert((last?.whiteLists?.count)! <= Constants.userWhiteListMax,
                              "Bad count: Expected \(Constants.userWhiteListMax), got \(last?.whiteLists?.count as Int?).")
                    if shouldEnd { expect.fulfill() }
                })
        }
    }
}
