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
class UserAfterRuleListsTests: XCTestCase {
    let testSource = RemoteBlockList.self
    let timeout: TimeInterval = 10
    var bag: DisposeBag!
    var user: User!
    var wkcb: WebKitContentBlocker!

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
        wkcb.ruleListAllClearers()
            .subscribe(onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                unlock.accept(true)
            }).disposed(by: bag)
        let waitDone = try? unlock.asObservable()
            .skip(1)
            .toBlocking(timeout: timeout / 2.0)
            .first()
        XCTAssert(waitDone == true,
                  "Failed to clear rules.")
    }

    /// Integration test:
    /// Test adding rule lists generated from downloads.
    func testUserAfterRL() {
        let expect = expectation(description: #function)
        let lastUser = UserUtility().lastUser
        var switched: User!
        DownloadUtility().downloadForUser(
            lastUser,
            afterUserSavedTest: { saved in
                do {
                    let updated = try UserBlockListDownloader(user: saved)
                        .userBlockListUpdated()(saved)
                    self.wkcb.rulesAddedWKStore(user: updated)
                        .flatMap { rlst -> Observable<WKContentRuleList> in
                            XCTAssert(rlst.identifier == updated.blockList?.name,
                                      "Bad rule list.")
                            switched = self.aaSwitched(user: updated)
                            return self.wkcb.rulesAddedWKStore(user: switched)
                        }
                        .subscribe(onNext: { rlst in
                            XCTAssert(rlst.identifier == switched.blockList?.name,
                                      "Bad rule list.")
                        }, onError: { err in
                            XCTFail("Error: \(err)")
                        }, onCompleted: {
                            expect.fulfill()
                        }).disposed(by: self.bag)
                } catch let err { XCTFail("Error: \(err)") }
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout * 4.0)
    }

    private
    func aaSwitched(user: User) -> User {
        XCTAssert(user.downloads?.count == testSource.allCases.count,
                  "Bad DL count.")
        let newList = user.downloads?.filter { $0.name != user.blockList?.name }
        XCTAssert(newList?.count == 1,
                  "Bad list count.")
        var copy = user
        if let blst = newList?.first { copy.blockList = blst } else { XCTFail("List not found.") }
        return copy
    }
}
