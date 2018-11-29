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

class UserStateFutureTests: XCTestCase {
    let testSource = RemoteBlockList.self
    let timeout: TimeInterval = 10
    var bag: DisposeBag!
    var dler: UserBlockListDownloader!
    var user: User!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        do {
            try user = User()
            let blst = try BlockList(withAcceptableAds: true,
                                     source: testSource.easylistPlusExceptions)
            user.blockList = blst
            try user.save()
            // Pass user state:
            dler = UserBlockListDownloader(user: user)
        } catch let err { XCTFail("Error: \(err)") }
    }

    /// Integration test:
    func testUserAfterDL() throws {
        let expect = expectation(description: #function)
        let expectedDLs = testSource.allCases.count
        guard let user = try User(fromPersistentStorage: true) else { throw ABPUserModelError.badDataUser }
        let start = user // copy
        dler.userAfterDownloads()(dler.userSourceDownloads())
            .subscribe(onNext: { user in
                guard let rslt = try? User(fromPersistentStorage: true),
                      let end = rslt
                else { XCTFail("Bad user."); return }
                XCTAssert(start == end,
                          "Bad equivalence for persisted.")
                try? self.dler.syncDownloads()(user).save()
                let synced = try? User(fromPersistentStorage: true)
                XCTAssert(synced??.downloads?.count == expectedDLs,
                          "Bad count.")
                XCTAssert(synced??.name == start.name,
                          "Bad user.")
            }, onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }

    func testUserAfterDLWithError() throws {
        let expect = expectation(description: #function)
        let mockError = ABPDownloadTaskError.failedMove
        guard var user = try User(fromPersistentStorage: false) else { throw ABPUserModelError.badDataUser }
        let blst = try BlockList(withAcceptableAds: true, source: RemoteBlockList.easylistPlusExceptions)
        user.blockList = blst
        dler.userAfterDownloads()(MockEventer(error: mockError).mockObservable())
            .subscribe(onError: { err in
                XCTAssert(err as? ABPDownloadTaskError == mockError,
                          "Bad error.")
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }
}
