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

/// Tests future user states.
class UserAfterDownloadsTests: XCTestCase {
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

    /// Integration test:
    func testUserAfterDL() throws {
        let expect = expectation(description: #function)
        let expectedDLs = testSource.allCases.count
        let start = user // copy
        let lastUser = UserUtility().lastUser
        DownloadUtility().downloadForUser(
            lastUser,
            afterDownloadTest: {
                XCTAssert(lastUser(true) == start,
                          "Bad equivalence for persisted.")
            },
            afterUserSavedTest: { saved in
                // User BL not updated after DLs:
                XCTAssert(saved.blockList == start?.blockList,
                          "Bad blocklist.")
                XCTAssert(saved.downloads?.count == expectedDLs,
                          "Bad count.")
                XCTAssert(saved.name == start?.name,
                          "Bad user.")
                let updated = try? UserBlockListDownloader(user: saved)
                    .userBlockListUpdated()(saved)
                if let dls = updated?.downloads, let blst = updated?.blockList {
                    XCTAssert(dls.contains(blst),
                              "List not found.")
                } else { XCTFail("Missing lists.") }
            },
            withCompleted: { expect.fulfill() }
        ).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }

    func testUserAfterDLWithError() throws {
        let expect = expectation(description: #function)
        let mockError = ABPDownloadTaskError.failedMove
        UserBlockListDownloader(user: user)
            .userAfterDownloads()(MockEventer(error: mockError).mockObservable())
            .subscribe(onError: { err in
                XCTAssert(err as? ABPDownloadTaskError == mockError,
                          "Bad error.")
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }
}
