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

class ContentBlockerUtilityTests: XCTestCase {
    let timeout: TimeInterval = 5
    let whitelistDomains =
        ["test1.com",
         "test2.com",
         "test3.com"]
    var bag: DisposeBag!
    var relay: AppExtensionRelay!
    var testingFile: URL?
    var cbUtil: ContentBlockerUtility!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        do {
            cbUtil = try ContentBlockerUtility()
        } catch let err { XCTFail("Error: \(err)") }
        relay = AppExtensionRelay.sharedInstance()
    }

    override
    func tearDown() {
        if testingFile != nil { removeFile(testingFile!) }
        super.tearDown()
    }

    /// Test getting filter list name
    ///
    /// This still needs to handle custom filter lists once that feature is
    /// fully implemented.
    /// See https://gitlab.com/eyeo/auxiliary/issue/issues/84.
    func testActiveFilterListName() {
        var name: String?
        setupABPState(state: .defaultFilterListEnabled)
        name = cbUtil.activeFilterListName()
        XCTAssert(name == "easylist",
                  "Default filter name is wrong.")
        setupABPState(state: .acceptableAdsEnabled)
        name = cbUtil.activeFilterListName()
        XCTAssert(name == "easylist+exceptionrules",
                  "AA filter list name is wrong.")
    }

    func testMakeWhitelistRules() {
        let domain = "test.com"
        let type = "ignore-previous-rules"
        do {
            let data = try JSONEncoder().encode(cbUtil.whiteListRuleForDomain()(domain))
            let decoded: BlockingRule = try JSONDecoder().decode(BlockingRule.self, from: data)
            XCTAssert(decoded.action?.selector == nil,
                      "Bad action selector.")
            XCTAssert(decoded.action?.type == type,
                      "Bad action type.")
            if decoded.trigger?.ifTopURL != nil {
                XCTAssert(decoded.trigger?.ifTopURL![0] == cbUtil.wrappedDomain()(domain),
                          "Bad trigger ifTopURL.")
            } else { XCTFail("Bad trigger ifTopURL - missing.") }
            XCTAssert(decoded.trigger?.loadType == nil,
                      "Bad trigger loadType.")
            XCTAssert(decoded.trigger?.resourceType == nil,
                      "Bad trigger resourceType.")
            XCTAssert(decoded.trigger?.unlessTopURL == nil,
                      "Bad trigger unlessDomain.")
            XCTAssert(decoded.trigger?.urlFilterIsCaseSensitive == false,
                      "Bad trigger urlFilterIsCaseSensitive.")
        } catch let error { XCTFail("Bad rule with error: \(error)") }
    }

    /// Included within are tests for the following:
    /// * test getting a blocklist on disk
    func testMergeWhitelistedWebsites() throws {
        let expect = expectation(description: #function)
        let ruleMax = 1 // max rules to read
        setupABPState(state: .defaultFilterListEnabled)
        let source = try localTestFilterListRules()
        var destURL: BlockListFileURL?
        cbUtil.mergedFilterListRules(from: source,
                                     with: whitelistDomains,
                                     limitRuleMaxCount: true)
            .subscribe(onNext: { fileURL in
                destURL = fileURL
            }, onError: { error in
                XCTFail("Failed with error: \(error)")
            }, onCompleted: {
                do {
                    if destURL == nil { XCTFail("Bad destination URL.") }
                    let data = try self.cbUtil.blocklistData(blocklist: destURL!)
                    self.ruleCount(rules: data, completion: { cnt in
                        XCTAssert(cnt == ruleMax + self.whitelistDomains.count,
                                  "Rule count is wrong.")
                    })
                } catch let error { XCTFail("Failed with error: \(error)") }
                expect.fulfill()
            }).disposed(by: bag)
        waitForExpectations(timeout: timeout)
    }

    /// Version of merge testing that doesn't use RxSwift inside ABPKit.
    /// Included within are tests for the following:
    /// * test getting a blocklist on disk
    func testMergeWhitelistedWebsitesNonRx() throws {
        let expect = expectation(description: #function)
        let fmgr = FileManager.default
        let filename = "testfile"
        let ruleMax = 1 // max rules to read
        let encoder = JSONEncoder()
        let encoded: (BlockingRule?) -> Data = {
            // Empty Data only in testing:
            guard let data = try? encoder.encode($0) else { XCTFail("Failed encoding."); return Data() }
            return data
        }
        let rules = try localTestFilterListRules()
        let rulesDir = cbUtil.rulesDir(blocklist: rules)
        let fileurl = cbUtil.makeNewBlocklistFileURL(name: filename, at: rulesDir)
        setupABPState(state: .defaultFilterListEnabled)
        var rule: BlockingRule?
        var cnt = 0
        testingFile = fileurl
        try cbUtil.startBlockListFile(blocklist: fileurl)
        guard let rulesData = fmgr.contents(atPath: rules.path) else { XCTFail("Bad rules."); return }
        try JSONDecoder().decode(V1FilterList.self, from: rulesData).rules()
            .takeWhile { _ in cnt < ruleMax }
            .subscribe(onNext: { rule in
                cnt += 1
                self.cbUtil.writeToEndOfFile(blocklist: fileurl, with: encoded(rule))
                self.cbUtil.addRuleSeparator(blocklist: fileurl)
            }, onCompleted: {
                self.whitelistDomains.forEach {
                    rule = self.cbUtil.whiteListRuleForDomain()($0)
                    self.cbUtil.writeToEndOfFile(blocklist: fileurl, with: encoded(rule))
                    self.cbUtil.addRuleSeparator(blocklist: fileurl)
                }
                self.cbUtil.endBlockListFile(blocklist: fileurl)
                do {
                    self.ruleCount(rules: try self.cbUtil.blocklistData(blocklist: fileurl),
                                   completion: { cnt in
                        XCTAssert(cnt == ruleMax + self.whitelistDomains.count,
                                  "Rule count is wrong.")
                        expect.fulfill()
                    })
                } catch let error { XCTFail("Failed with error: \(error)") }
            }).disposed(by: bag)
        waitForExpectations(timeout: timeout)
    }

    // ------------------------------------------------------------
    // MARK: - Private -
    // ------------------------------------------------------------

    private
    func localTestFilterListRules() throws -> BlockListFileURL {
        var list = try FilterList()
        list.name = "v1 easylist short"
        list.fileName = "v1 easylist short.json"
        // Adding a list for testing to the relay does not work because the host
        // app loads its own lists into the relay.
        try Persistor().saveFilterListModel(list)
        if let url = try list.rulesURL(bundle: Bundle(for: ContentBlockerUtilityTests.self)) {
            return url
        } else { throw ABPFilterListError.missingRules }
    }

    private
    func ruleCount(rules: Data,
                   completion: @escaping (Int) -> Void) {
        var cnt = 0
        do {
            try JSONDecoder().decode(V1FilterList.self, from: rules).rules()
                .subscribe(onNext: { _ in
                    cnt += 1
                }, onError: { error in
                    XCTFail("Failed with error: \(error)")
                }, onCompleted: {
                    completion(cnt)
                }).disposed(by: bag)
        } catch let error { XCTFail("Failed with error: \(error)") }
    }

    private
    enum ABPState: String {
        case defaultFilterListEnabled
        case acceptableAdsEnabled
    }

    private
    func setupABPState(state: ABPState) {
        relay.enabled.accept(true)
        switch state {
        case .defaultFilterListEnabled:
            relay.defaultFilterListEnabled.accept(true)
            relay.acceptableAdsEnabled.accept(false)
        case .acceptableAdsEnabled:
            relay.defaultFilterListEnabled.accept(false)
            relay.acceptableAdsEnabled.accept(true)
        }
    }

    private
    func removeFile(_ fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let err { XCTFail("Remove failed for: \(fileURL)) with error: \(err)"); return }
    }
}
