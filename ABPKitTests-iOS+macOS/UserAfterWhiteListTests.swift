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
    /// Test domains.
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

    func testMakeWhiteListRuleForDomains() throws {
        user.whitelistedDomains = RandomStateUtility().randomState(for: [String].self)
        let rule = try ContentBlockerUtility().whiteListRuleForUser()(user)
        XCTAssert(rule.trigger?.ifTopURL?.count == user.whitelistedDomains?.count,
                  "Bad count.")
    }

    func testPercentCharacter() throws {
        user.whitelistedDomains = RandomStateUtility().randomState(for: [String].self)
        try ContentBlockerUtility().whiteListRuleForUser()(user)
            .trigger?.ifTopURL?.forEach {
                XCTAssert($0.contains("%"),
                          "Missing '%' character in ifTopURL \($0).")
            }
    }

    func testMultiDomainRuleToList() throws {
        let expect = expectation(description: #function)
        let name = "user-whitelist"
        user.whitelistedDomains = RandomStateUtility().randomState(for: [String].self)
        let cbUtil = try ContentBlockerUtility()
        let whitelistRuleAddForUser: (User) -> Observable<WKContentRuleList> = { user in
            guard let dmns = user.whitelistedDomains else {
                return Observable.error(ABPUserModelError.badDataUser)
            }
            let rule = cbUtil.whiteListRuleForDomains()(dmns)
            XCTAssert(rule.trigger?.ifTopURL?.count == dmns.count,
                      "Bad count.")
            return self.wkcb.concatenatedRules()(Observable.from([rule]))
                .flatMap { result -> Observable<WKContentRuleList> in
                    return self.wkcb.rulesCompiledForIdentifier(name)(result.0)
                }
        }
        whitelistRuleAddForUser(user)
            .subscribe(onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }
}
