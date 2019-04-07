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
import XCTest

class UserBlockListDownloadTests: XCTestCase {
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
            user = try UserUtility().aaUserNewSaved(testSource.easylistPlusExceptions)
            dler = UserBlockListDownloader(user: user, logWith: { log("🗑️\($0)") })
        } catch let err { XCTFail("Error: \(err)") }
    }

    override
    func tearDown() {
        dler = nil
        super.tearDown()
    }

    func testRemoteBlockListCases() throws {
        let lists = try testSource.allCases
            .map { try DownloadUtility().blockListForSource()($0) }
        try XCTAssert(lists
            .filter { try AcceptableAdsHelper().aaExists()($0.source) }.count == 1,
                      "Bad count.")
    }

    func testHashable() throws {
        var lists = [BlockList]()
        for _ in 0...Int.random(in: 100...1000) {
            lists.append(try BlockList(withAcceptableAds: true, source: testSource.easylistPlusExceptions))
        }
        user.downloads = lists
        guard let dls = user.downloads else { throw ABPUserModelError.badDownloads }
        XCTAssert(Set<BlockList>(dls).count == dls.count,
                  "Bad count.")
    }

    func testExpired() throws {
        var list = try BlockList(withAcceptableAds: true, source: testSource.easylistPlusExceptions)
        list.dateDownload = Date().addingTimeInterval(-Constants.defaultFilterListExpiration - 1)
        XCTAssert(list.isExpired() == true,
                  "Bad expiration.")
        list.dateDownload = Date().addingTimeInterval(-Constants.defaultFilterListExpiration + 1)
        XCTAssert(list.isExpired() == false,
                  "Bad expiration.")
    }

    func testMockFailure() {
        var evtCnt = 0
        var errAt = 0
        let mockError = ABPDownloadTaskError.failedCopy
        let evtr = MockEventer(error: mockError)
        evtr.mockObservable()
            .subscribe(onNext: { _ in
                evtCnt += 1
            }, onError: { err in
                errAt = evtCnt
                XCTAssert(err as? ABPDownloadTaskError == mockError,
                          "Bad error.")
                XCTAssert(evtr.expectedEvents + evtr.expectedErrorOffset == evtCnt,
                          "Bad count: \(evtCnt) - expected \(evtr.expectedEvents + evtr.expectedErrorOffset).")
                XCTAssert(errAt == evtr.expectedEvents + evtr.expectedErrorOffset,
                          "Bad error at count: \(errAt)")
            }, onCompleted: {
                XCTFail("Failed to error.")
            }).disposed(by: bag)
    }

    /// Integration test:
    ///
    /// Does not overload download syncing as with testDownloadMultiple().
    func testDownloadSourceForUser() throws {
        var dlEvents = [Int: UserDownloadEvent]()
        let unlocked = BehaviorRelay<Bool>(value: false)
        try Persistor().clearRulesFiles()
        // Downloader has state dependency on source DLs:
        dler.srcDownloads = try dler.blockListDownloads()(user)
        // Downloader has state dependency on download events:
        dler.downloadEvents = dler.makeDownloadEvents()(dler.srcDownloads)
        var completeCount = 0
        dler.downloadEvents.forEach { key, val in
            val.asObservable()
                .subscribe(onNext: {
                    dlEvents[key] = $0
                }, onError: { err in
                    XCTFail("DL error: \(err)")
                }, onCompleted: {
                    XCTAssert(dlEvents[key]?.didFinishDownloading == true,
                              "Bad DL state.")
                    completeCount += 1
                    if completeCount >= self.dler.srcDownloads.count {
                        unlocked.accept(true)
                    }
                }).disposed(by: bag)
        }
        let waitDone = try? unlocked.asObservable()
            .skip(1)
            .toBlocking(timeout: timeout)
            .first()
        XCTAssert(waitDone == true,
                  "Timed out.")
        let exists = try dler.srcDownloads.map {
            $0.blockList?.name.addingFileExtension(Constants.rulesExtension)
        }.compactMap {
            try FileManager.default.fileExists(atPath: Config().containerURL().appendingPathComponent($0!).path)
        }
        XCTAssert(exists.filter { !$0 }.count == 0,
                  "Bad count: Expected \(0), got \(exists.filter { !$0 }.count).")
    }

    /// Integration test:
    ///
    /// Performs multiple downloads to fill up the user downloads and local
    /// storage for download sync testing.
    ///
    /// Network conditions may require longer timeout.
    ///
    /// Completion of downloadSubscription may occasionally happen after outer
    /// completion but the results should be the same. An extra take is required
    /// for this implementation due to the overlap of subscriptions.
    func testDownloadMultiple() throws {
        let expect = expectation(description: #function)
        let iterMax = Int((Double(Constants.userBlockListMax) / Double(testSource.allCases.count)).rounded(.up)) + 1
        let pstr = try Persistor()
        let lastUser = UserUtility().lastUser
        Observable<Int>
            .interval(timeout, scheduler: MainScheduler.asyncInstance)
            .startWith(-1)
            .take(iterMax)
            .subscribe(onNext: { _ in
                DownloadUtility().downloadForUser(lastUser).disposed(by: self.bag)
            }, onCompleted: {
                do {
                    let synced = try (lastUser(true).map { try self.dler.syncDownloads()($0) })?.saved()
                    log("👩‍🎤multicomplete downloads #\(synced?.downloads?.count as Int?) - \(synced?.downloads as [BlockList]?)")
                    let user = lastUser(true)
                    XCTAssert(user?.downloads?.count == Constants.userBlockListMax,
                              "Bad count downloads: Expected \(Constants.userBlockListMax), got \(user?.downloads?.count as Int?).")
                    let fcnt = try pstr.jsonFiles()(pstr.fileEnumeratorForRoot()(Config().containerURL())).count
                    XCTAssert(fcnt == user?.downloads?.count,
                              "Bad count: Expected \(user?.downloads?.count as Int?), got \(fcnt).")
                } catch let err { XCTFail("Error: \(err)") }
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout * Double(iterMax) * 1.2)
    }
}
