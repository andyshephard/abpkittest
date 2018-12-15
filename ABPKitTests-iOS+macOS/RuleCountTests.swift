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
import XCTest

class RuleCountTests: XCTestCase {
    var bag = DisposeBag()
    let timeout: TimeInterval = 8
    /// Value is rule count.
    let testLists = ["test-v1-easylist-short": 7,
                     "test-v2-easylist-short": 7,
                     "test-v2-easylist-short-partial": 0,
                     "test-easylist_content_blocker": 21475]

    func testRuleCounting() throws {
        let expect = expectation(description: #function)
        let pstr = try Persistor()
        try testLists.forEach { key, _ in
            var list = try FilterList()
            list.name = UUID().uuidString
            list.fileName = key + "." + Constants.rulesExtension
            try pstr.saveFilterListModel(list)
            list.ruleCount(bundle: Bundle(for: RuleCountTests.self))
                .subscribe(onNext: { cnt in
                    XCTAssert(cnt == self.testLists[key],
                              "Rule count of \(cnt) doesn't match \(self.testLists[key] as Int?) for \(key)")
                }, onError: { err in
                    XCTFail("Error: \(err)")
                }).disposed(by: bag)
        }
        expect.fulfill()
        wait(for: [expect], timeout: timeout, enforceOrder: true)
    }
}
