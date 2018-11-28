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
            try user.save()
            let blst = try BlockList(withAcceptableAds: true,
                                     source: RemoteBlockList.easylistPlusExceptions)
            user.blockList = blst
            // User state passed in:
            dler = UserBlockListDownloader(user: user)
        } catch let err { XCTFail("Error: \(err)") }
    }

    func testRemoteBlockListCases() throws {
        let lists = try RemoteBlockList.allCases
            .map { try blockListForSource()($0) }
        XCTAssert(lists.filter { $0.source.hasAcceptableAds() }.count == 1,
                  "Bad count.")
    }

    func testHashable() throws {
        var lists = [BlockList]()
        for _ in 0...Int.random(in: 100...1000) {
            lists.append(try BlockList(withAcceptableAds: true, source: RemoteBlockList.easylistPlusExceptions))
        }
        user.downloads = lists
        guard let dls = user.downloads else { throw ABPUserModelError.badDownloads }
        XCTAssert(Set<BlockList>(dls).count == dls.count,
                  "Bad count.")
    }

    /// Does not overload download syncing as with testDownloadMultiple().
    func testDownloadSourceForUser() throws {
        var dlEvents = [Int: UserDownloadEvent]()
        let unlocked = BehaviorRelay<Bool>(value: false)
        try Persistor().clearRulesFiles()
        // Downloader has state dependency on source DLs:
        dler.srcDownloads = try dler.blockListDownloads()(user)
        // Downloader has state dependency on download events:
        dler.downloadEvents = downloadEvents()(dler.srcDownloads)
        var completeCount = 0
        dler.downloadEvents.forEach { key, val in
            val.asObservable()
                .subscribe(onNext: {
                    XCTAssert($0.error == nil,
                              "DL error: \(String(describing: $0.error))")
                    dlEvents[key] = $0
                },
                onCompleted: {
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
        let mgr = FileManager.default
        let root = try Config().containerURL()
        let exists = dler.srcDownloads.map {
            $0.blockList?.name.addingFileExtension(Constants.rulesExtension)
        }.compactMap {
            mgr.fileExists(atPath: root.appendingPathComponent($0!).path)
        }
        XCTAssert(exists.filter { !$0 }.count == 0,
                  "Bad count.")
    }

    /// Integration test that performs multiple downloads to fill up the user
    /// downloads and local storage for download sync testing.
    func testDownloadMultiple() throws {
        let expect = expectation(description: #function)
        let iterMax = 4
        let pstr = try Persistor()
        Observable<Int>
            .interval(timeout, scheduler: MainScheduler.asyncInstance)
            .take(iterMax)
            .subscribe(onNext: { _ in
                self.downloadSubscription().disposed(by: self.bag)
            }, onCompleted: {
                if let user = try? User(fromPersistentStorage: true), user != nil {
                    let synced = try? self.dler.syncDownloads()(user!)
                    if synced != nil {
                        try? synced!.save()
                        log("👩‍🎤downloads #\(String(describing: synced!.downloads?.count)) - \(String(describing: synced!.downloads))")
                        let user = try? User(fromPersistentStorage: true)
                        XCTAssert(user??.downloads?.count == Constants.userBlockListMax,
                                  "Bad count downloads.")
                        do {
                            let fcnt = try pstr.jsonFiles()(pstr.fileEnumeratorForRoot()(Config().containerURL())).count
                            XCTAssert(fcnt == user??.downloads?.count,
                                      "Bad count files.")
                        } catch let err { XCTFail("Error: \(err)") }
                    }
                }
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout * Double(iterMax))
    }

    private
    func downloadSubscription() -> Disposable {
        return downloadUserSource()
            .subscribe(onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                let user = try? User(fromPersistentStorage: true)
                log("👩‍🎤downloads #\(String(describing: user??.downloads?.count)) - \(String(describing: user??.downloads))")
            })
    }

    /// Return an observable of all concatenated user dl events.
    private
    func downloadUserSource() -> Observable<UserDownloadEvent> {
        do {
            // Downloader has state dependency on source DLs:
            dler.srcDownloads = try dler.blockListDownloads()(user)
            // Downloader has state dependency on download events:
            dler.downloadEvents = downloadEvents()(self.dler.srcDownloads)
            return Observable.concat(dler.downloadEvents.map { $1 })
        } catch { return Observable.error(ABPUserModelError.badDownloads) }
    }

    private
    func downloadEvents() -> ([SourceDownload]) -> (TaskDownloadEvent) {
        return {
            Dictionary(uniqueKeysWithValues: $0
                .map { $0.task?.taskIdentifier }
                .compactMap {
                    ($0!, BehaviorSubject<UserDownloadEvent>(value: UserDownloadEvent()))
                })
        }
    }

    private
    func blockListForSource() -> (BlockListSourceable & RulesDownloadable) throws -> BlockList {
        return {
            return try BlockList(withAcceptableAds: $0.hasAcceptableAds(), source: $0)
        }
    }
}
