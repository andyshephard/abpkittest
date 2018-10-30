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

class BlockListDownloadTests: XCTestCase {
    let mdlr = FilterListTestModeler()
    let timeout: TimeInterval = 15
    let totalBytes = Int64(9383979)
    let totalRules = 45899
    let vldtr = RulesValidator()
    var bag: DisposeBag!
    var dler: BlockListDownloader!
    var filterLists = [FilterList]()
    var pstr: Persistor!
    var testList: FilterList!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        dler = BlockListDownloader()
        dler.isTest = true
        pstr = Persistor()
        do {
            try pstr.clearFilterListModels()
        } catch let err {
            XCTFail("Failed to clear models with error: \(err)")
            return
        }
        guard let list = try? mdlr.localBlockList() else {
            XCTFail("Failed to make test list.")
            return
        }
        testList = list
        guard let result = try? pstr.saveFilterListModel(testList),
              result == true
        else {
            XCTFail("Failed to save test list.")
            return
        }
    }

    func testRemoteSource() {
        testList.source = "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json"
        testList.fileName = "easylist_content_blocker.json"
        guard let result = try? self.pstr.saveFilterListModel(self.testList),
                  result == true
        else {
            XCTFail("Failed to save test list.")
            return
        }
        runDownloadDelegation(remoteSource: true)
    }

    func testLocalSource() {
        runDownloadDelegation()
    }

    func runDownloadDelegation(remoteSource: Bool = false) {
        let expect = expectation(description: #function)
        var cnt = 0
        dler.blockListDownload(for: testList,
                               runInBackground: false)
            .flatMap { task -> Observable<DownloadEvent> in
                task.resume()
                return self.downloadEvents(for: task)
            }
            .flatMap { evt -> Observable<DownloadEvent> in
                XCTAssert(evt.error == nil,
                          "🚨 Error during event handling: \(String(describing: evt.error?.localizedDescription)))")
                return Observable.just(evt)
            }
            .filter {
                $0.didFinishDownloading == true &&
                $0.errorWritten == true
            }
            .flatMap { evt -> Observable<BlockingRule> in
                return self.downloadedRules(for: evt,
                                            remoteSource: remoteSource)
            }
            .subscribe(onNext: { rule in
                cnt += [rule].count
            }, onCompleted: {
                if !remoteSource {
                    XCTAssert(cnt == self.totalRules,
                              "Rule count is wrong.")
                }
                expect.fulfill()
            }).disposed(by: bag)
            wait(for: [expect],
                 timeout: timeout)
    }

    func downloadEvents(for task: URLSessionDownloadTask) -> Observable<DownloadEvent> {
        let taskID = task.taskIdentifier
        self.testList.taskIdentifier = taskID
        guard let result = try? self.pstr.saveFilterListModel(self.testList),
              result == true
        else {
            XCTFail("Failed to save test list.")
            return Observable.empty()
        }
        self.setupEvents(taskID: taskID)
        guard let subj = self.dler.downloadEvents[taskID] else {
            XCTFail("Bad publish subject.")
            return Observable.empty()
        }
        return subj.asObservable()
    }

    func downloadedRules(for finalEvent: DownloadEvent,
                         remoteSource: Bool = false) -> Observable<BlockingRule> {
        self.testList.downloaded = true
        guard let result = try? self.pstr.saveFilterListModel(self.testList),
              result == true
        else {
            XCTFail("Failed to save test list.")
            return Observable.empty()
        }
        if !remoteSource {
            XCTAssert(finalEvent.totalBytesWritten == self.totalBytes,
                      "🚨 Bytes wrong.")
        }
        guard let name = self.testList.name else {
            XCTFail("Bad model name.")
            return Observable.empty()
        }
        let util = ContentBlockerUtility()
        guard let url = try? util.getRulesURL(for: name),
              let rulesURL = url
        else {
            XCTFail("Bad rules URL.")
            return Observable.empty()
        }
        return self.vldtr.validatedRules(for: rulesURL)
    }

    private
    func setupEvents(taskID: DownloadTaskID) {
        dler.downloadEvents[taskID] =
            BehaviorSubject<DownloadEvent>(
                value: DownloadEvent(filterListName: self.testList.name,
                                     didFinishDownloading: false,
                                     totalBytesWritten: 0,
                                     error: nil,
                                     errorWritten: false))
    }
}