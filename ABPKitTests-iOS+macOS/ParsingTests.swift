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

class ParsingTests: XCTestCase {
    /// Expected number of test rules.
    let testingRuleCount = 7
    /// Expected v2 expires
    let testingExpires = "4 days"
    /// Expected v2 version.
    let testingVersion = "201812121930"
    /// Expected v2 source url.
    let testingSources: FilterListV2Sources =
        [["version": "201812121930",
          "url": "https://easylist-downloads.adblockplus.org/easylist_noadult.txt"]]
    /// Expected v2 test count.
    let testingV2TestCount = 2
    var localPath: String!
    var v1FileURL: URL!
    var v2FileURL: URL!
    var v2PartialFileURL: URL!
    var bag: DisposeBag!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        let util = TestingFileUtility()
        // Load test filter list URLs:
        v1FileURL = util.fileURL(resource: "test-v1-easylist-short", ext: Constants.rulesExtension)
        v2FileURL = util.fileURL(resource: "test-v2-easylist-short", ext: Constants.rulesExtension)
        v2PartialFileURL = util.fileURL(resource: "test-v2-easylist-short-partial", ext: Constants.rulesExtension)
    }

    func testRulesValidation() throws {
        let expect = expectation(description: #function)
        let timeout: TimeInterval = 5
        guard let url = v1FileURL else {
            XCTFail("Missing url")
            return
        }
        var cnt = 0
        try RulesHelper()
            .validatedRules()(url)
            .subscribe(onNext: { rule in
                cnt += [rule].count
            }, onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                expect.fulfill()
            }).disposed(by: bag)
        waitForExpectations(timeout: timeout) { _ in
            XCTAssert(cnt == self.testingRuleCount,
                      "Wrong rule count.")
        }
    }

    /// Test parsing v1 filter lists.
    func testParsingV1FilterList() {
        guard let url = v1FileURL else { XCTFail("Missing url"); return }
        let decoder = JSONDecoder()
        do {
            let list = try decoder.decode(V1FilterList.self, from: filterListData(url: url))
            var rules = [BlockingRule]()
            list.rules()
                .subscribe(onNext: { rule in
                    rules.append(rule)
                }, onError: { err in
                    XCTFail("Error: \(err)")
                }).disposed(by: bag)
            XCTAssert(rules.count == testingRuleCount,
                      "Wrong rule count")
        } catch let error { XCTFail("Decode failed with error: \(error)") }
    }

    /// Sort FilterListV2Sources based on the url key.
    /// - parameter sources: Contents of the v2 filter list sources key
    /// - returns: Sorted FilterListV2Sources
    /// - throws: ABPFilterListError
    private
    func sort(_ sources: FilterListV2Sources) throws -> FilterListV2Sources {
        let key = "url"
        return try sources.sorted {
            if let valA = $0[key], let valB = $1[key] {
                return valA < valB
            } else { throw ABPFilterListError.invalidData }
        }
    }

    /// For a dictionary A, check that its key-value pairs match those in dictionary B.
    /// - parameters:
    ///   - dictA: A dictionary to be compared
    ///   - dictB: A dictionary to be compared
    /// - returns: True if equal, otherwise false
    private
    func equal<T>(dictA: [T: T], dictB: [T: T]) -> Bool {
        var mismatch = false
        dictA.keys.forEach { key in
            if dictA[key] != dictB[key] { mismatch = true }
        }
        return !mismatch
    }

    /// Get filter list data.
    /// - parameter url: File URL of the data
    /// - returns: Data of the filter list
    /// - throws: ABPKitTestingError
    private
    func filterListData(url: URL) throws -> Data {
        return try Data(contentsOf: url, options: .uncached)
    }

    /// V2 test cases.
    enum V2ParseTestType: String,
                          CaseIterable {
        case short
        case partial
    }

    private
    func runV2ParsingTest(type: V2ParseTestType) {
        var url: URL!
        switch type {
        case .short:
            url = v2FileURL
        case .partial:
            url = v2PartialFileURL
        }
        let decoder = JSONDecoder()
        do {
           let list = try decoder.decode(V2FilterList.self, from: filterListData(url: url))
            var rules = [BlockingRule]()
            list.rules().subscribe(onNext: { rule in
                rules.append(rule)
            }, onError: { err in
                XCTFail("Error: \(err)")
            }).disposed(by: bag)
            XCTAssert(rules.count == testingRuleCount,
                      "Wrong rule count")
            XCTAssert(list.expires == testingExpires,
                      "Wrong expires")
            XCTAssert(list.version == testingVersion,
                      "Wrong version")
            XCTAssert(testingSources.count == list.sources?.count,
                      "Wrong sources count")
            for idx in try 0...sort(testingSources).count - 1 {
                try XCTAssertTrue(equal(dictA: sort(testingSources)[idx], dictB: sort(list.sources ?? [])[idx]),
                                  "Wrong sources")
            }

        } catch let err { if [.short].contains(type) { XCTFail("Decode failed with error: \(err)") } }
    }

    /// Test parsing v2 filter lists.
    func testV2FilterLists() {
        var cnt = 0
        V2ParseTestType
            .allCases
            .forEach {
                cnt += 1
                runV2ParsingTest(type: $0)
            }
        XCTAssert(cnt == testingV2TestCount,
                  "Wrong number of tests")
    }
}
