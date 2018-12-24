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
        pstr = Persistor()
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

    func testSaveLoadModelFilterListModels() {
        let testCount = Int.random(in: 1...10)
        // swiftlint:disable unused_optional_binding
        guard let _ = try? testModeler.populateTestModels(count: testCount) else {
            XCTFail("Failed populating models.")
            return
        }
        // swiftlint:enable unused_optional_binding
        guard let savedModels = try? pstr.loadFilterListModels() else {
            XCTFail("Failed load.")
            return
        }
        XCTAssert(savedModels.count == testCount)
    }

    /// Somehow the file manager doesn't give an error when removing a bundled filter list for the first time.
    /// Therefore, the first test list will be reported as deleted though no removal actually occurs.
    func testClearFilterListModels() {
        let testCount = Int.random(in: 2...10)
        // swiftlint:disable unused_optional_binding
        guard let _ =
            try? testModeler
                .populateTestModels(count: testCount,
                                    bundledRules: false)
        else {
            XCTFail("Failed populating models.")
            return
        }
        do {
            try pstr.logRulesFiles()
        } catch let err {
            XCTFail("Error during logging: \(err)")
        }
        guard let _ = try? pstr.clearFilterListModels() else {
            XCTFail("Failed clear.")
            return
        }
        // swiftlint:enable unused_optional_binding
        guard let models = try? pstr.loadFilterListModels() else {
            XCTFail("Failed to load models.")
            return
        }
        XCTAssert(models.count == 0,
                  "Model count mismatch.")
    }
}
