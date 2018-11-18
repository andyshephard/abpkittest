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

import XCTest

class PersistFilterListModelsTests: XCTestCase {
    var filterLists = [FilterList]()
    var pstr: Persistor!
    var testModeler: FilterListTestModeler!
    var util: TestingFileUtility!

    override
    func setUp() {
        super.setUp()
        if let uwrp = try? Persistor() { pstr = uwrp } else { XCTFail("Persistor failed init.") }
        testModeler = FilterListTestModeler()
        util = TestingFileUtility()
        // swiftlint:disable unused_optional_binding
        guard let _ = try? pstr.clearFilterListModels() else {
            XCTFail("Failed clear.")
            return
        }
        // swiftlint:enable unused_optional_binding
        // Remove all stored rules:
        do {
            try pstr.clearRulesFiles()
        } catch let err {
            XCTFail("Error during clearing: \(err)")
        }
    }

    func testSaveLoadModelFilterListModels() throws {
        let testCount = Int.random(in: 1...10)
        try testModeler.populateTestModels(count: testCount)
        let savedModels = try pstr.loadFilterListModels()
        XCTAssert(savedModels.count == testCount,
                  "Expected count of \(testCount) but received count of \(savedModels.count).")
    }

    /// Somehow the file manager doesn't give an error when removing a bundled filter list for the first time.
    /// Therefore, the first test list will be reported as deleted though no removal actually occurs.
    func testClearFilterListModels() throws {
        let testCount = Int.random(in: 2...10)
        try testModeler.populateTestModels(count: testCount,
                                           bundledRules: false)
        try pstr.logRulesFiles()
        try pstr.clearFilterListModels()
        guard let models = try? pstr.loadFilterListModels() else {
            XCTFail("Failed to load models.")
            return
        }
        XCTAssert(models.count == 0,
                  "Model count mismatch.")
    }

    func testFilterListInitRetrieval() throws {
        let list = try testModeler.makeLocalBlockList()
        let name = list.name
        try list.save()
        let savedModels = try pstr.loadFilterListModels()
        XCTAssert(savedModels
            .filter {
                $0.name == name
            }
            .count == 1,
            "List not found.")
    }
}
