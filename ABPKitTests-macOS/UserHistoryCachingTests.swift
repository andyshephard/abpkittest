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

import RxSwift
import WebKit
import XCTest

class UserHistoryCachingTests: XCTestCase {
    let timeout: TimeInterval = 10
    var bag: DisposeBag!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
    }

    func testClearBlockListHistory() throws {
        guard let saved = try User(fromPersistentStorage: true) else { XCTFail("No user."); return }
        try UserStateHelper(user: saved).clearBlockListHistory()
        guard let loaded = try User(fromPersistentStorage: true) else { XCTFail("No user."); return }
        XCTAssert(loaded.blockListHistory?.count == 0, "Bad count.")
    }

    /// Fill user history while adding rules.
    func testHistorySyncWithRuleLists() throws {
        let expect = expectation(description: #function)
        guard let wkcb = WebKitContentBlocker() else { XCTFail("Bad WebKitContentBlocker."); return }
        let blst = try BlockList(withAcceptableAds: true, source: BundledTestingBlockList.fakeExceptions)
        guard let user = try User(fromPersistentStorage: true) else { throw ABPUserModelError.badDataUser }
        var copy = user
        copy.setBlockList(blst)
        try copy.updateHistory()
        log("👩‍🎤hist cnt \(String(describing: copy.blockListHistory?.count))")
        wkcb.concatenatedRules(user: copy, customBundle: Bundle(for: UserHistoryCachingTests.self))
            .flatMap { rules, _ -> Observable<WKContentRuleList> in
                return wkcb.rulesCompiled(user: copy, rules: rules)
            }
            .flatMap { _ -> Observable<[String]?> in
                return wkcb.ruleIdentifiers()
            }
            .flatMap { ids -> Observable<Observable<String>> in
                let hist = copy.blockListHistory?.reduce([]) { $0 + [$1.name] }.sorted()
                log("1. hist - #\(String(describing: hist?.count)) - \(String(describing: hist))")
                log("1. store - #\(String(describing: ids?.count)) - \(String(describing: ids?.sorted()))")
                return wkcb.syncHistoryRemovers(user: copy)
            }
            .flatMap { remove -> Observable<String> in
                return remove
            }.flatMap { _ -> Observable<[String]?> in
                return wkcb.ruleIdentifiers()
            }
            .subscribe(onNext: { ids in
                let hist = copy.blockListHistory?.reduce([]) { $0 + [$1.name] }.sorted()
                log("2. hist - #\(String(describing: hist?.count)) - \(String(describing: hist))")
                log("2. store - #\(String(describing: ids?.count)) - \(String(describing: ids?.sorted()))")
            }, onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }
}
