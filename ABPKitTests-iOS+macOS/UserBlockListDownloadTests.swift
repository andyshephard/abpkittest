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
            dler = UserBlockListDownloader(user: user)
            let blst = try BlockList(withAcceptableAds: true,
                                     source: RemoteBlockList.easylistPlusExceptions)
            user.blockList = blst
        } catch let err { XCTFail("Error: \(err)") }
    }

    func testRemoteBlockListCases() throws {
        let lists = try RemoteBlockList.allCases
            .map { try blockListForSource()($0) }
        XCTAssert(lists.filter { $0.source.hasAcceptableAds() }.count == 1,
                  "Bad count.")
    }

    func testRemoteSourceDownloads() throws {
        let expect = expectation(description: #function)
        let unlocked = BehaviorRelay<Bool>(value: false)
        try Persistor().clearRulesFiles()
        dler.downloads = try dler.blockListDownloads()(user)
        dler.downloadEvents = Dictionary(uniqueKeysWithValues:
            dler.downloads
                .map { $0.task?.taskIdentifier }
                .compactMap {
                    ($0!, BehaviorSubject<UserDownloadEvent>(value: UserDownloadEvent()))
                })
        var completeCount = 0
        dler.downloadEvents.forEach {
            let (_, val) = $0
            val.asObservable()
                .subscribe(onNext: {
                    XCTAssert($0.error == nil,
                              "DL error: \(String(describing: $0.error))")
                },
                onCompleted: {
                    completeCount += 1
                    if completeCount >= self.dler.downloads.count {
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
        let exists = dler.downloads.map {
            $0.blockList?.name.addingFileExtension(Constants.rulesExtension)
        }.compactMap {
            mgr.fileExists(atPath: root.appendingPathComponent($0!).path)
        }
        XCTAssert(exists.filter { !$0 }.count == 0,
                  "Bad count.")
        expect.fulfill()
        wait(for: [expect], timeout: timeout)
    }

    private
    func blockListForSource() -> (BlockListSourceable & RulesDownloadable) throws -> BlockList {
        return {
            return try BlockList(withAcceptableAds: $0.hasAcceptableAds(), source: $0)
        }
    }
 }
