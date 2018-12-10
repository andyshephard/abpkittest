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

class UserSourceTests: XCTestCase {
    let lastUser = UserUtility().lastUser
    let testSource = RemoteBlockList.self
    let timeout: TimeInterval = 10
    var bag: DisposeBag!
    var user: User!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        do {
            try Persistor().clearRulesFiles()
            user = try UserUtility().aaUserNewSaved(testSource.easylistPlusExceptions)
        } catch let err { XCTFail("Error: \(err)") }
    }

    func testDownloadSourceMatch() {
        let expect = expectation(description: #function)
        let lastUser = UserUtility().lastUser
        DownloadUtility().downloadForUser(
            lastUser,
            afterUserSavedTest: { saved in
                do {
                    try RemoteBlockList.allCases.forEach {
                        let match = try UserStateHelper(user: saved).downloadsMatch()($0)
                        XCTAssert(match != nil,
                                  "Missing match for \($0).")
                    }
                } catch let err { XCTFail("Error: \(err)") }
            },
            withCompleted: { expect.fulfill() }
            ).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }
}
