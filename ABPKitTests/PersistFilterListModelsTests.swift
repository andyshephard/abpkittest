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
    let rulesExt = "json"
    var filterLists = [FilterList]()
    var pstr: Persistor!
    var testModeler: FilterListTestModeler!

    override
    func setUp() {
        super.setUp()
        pstr = Persistor()
        testModeler = FilterListTestModeler()
        // swiftlint:disable unused_optional_binding
        guard let _ = try? pstr.clearFilterListModels() else {
            XCTFail("Failed clear.")
            return
        }
        // swiftlint:enable unused_optional_binding
        // Remove all stored rules:
        listRulesFiles(remove: true)
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
        listRulesFiles(remove: false)
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

    private
    func listRulesFiles(remove: Bool = false) {
        let mgr = FileManager.default
        guard let url = try? Config().containerURL() else {
            XCTFail("Bad url.")
            return
        }
        guard let enmrtr =
            mgr.enumerator(at: url,
                           includingPropertiesForKeys: [.isDirectoryKey,
                                                        .nameKey],
                           options: [.skipsHiddenFiles,
                                    .skipsPackageDescendants],
                           errorHandler: { url, err -> Bool in
            XCTFail("Error during enumeration: \(err) for URL: \(url)")
            return true
        })
        else {
            XCTFail("Failed to make enumerator.")
            return
        }
        while let path = enmrtr.nextObject() as? URL {
            if path
                .lastPathComponent
                .split(separator: ".")
                .contains(Substring(rulesExt)) {
                if remove { try? mgr.removeItem(at: path) }
            }
        }
    }

}
