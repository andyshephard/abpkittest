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

import Foundation

/// Override testBundleFilename, if needed.
class FilterListTestModeler: NSObject {
    let cfg = Config()
    let testVersion = "20181020"
    var bundle: Bundle!
    var testBundleFilename = "test_easylist_content_blocker.json"

    override
    init() {
        super.init()
        bundle = Bundle(for: type(of: self))
    }

    /// This model object is for testing the delegate with local data.
    /// Returns a model filter list.
    func makeLocalBlockList(bundledRules: Bool = true) throws -> FilterList {
        let listName = "📜" + UUID().uuidString
        let listFilename = UUID().uuidString + "." + Constants.rulesExtension
        var list = FilterList()
        let fromBundle: () -> URL? = {
            guard let url =
                self.bundle
                    .url(forResource: self.testBundleFilename,
                         withExtension: "")
            else {
                return nil
            }
            return url
        }
        let fromContainer: () -> URL? = {
            let dler = BlockListDownloader()
            guard let src =
                self.bundle
                    .url(forResource: self.testBundleFilename,
                         withExtension: "")
            else {
                return nil
            }
            guard let containerURL = try? self.cfg.containerURL() else { return nil }
            let dst =
                containerURL
                    .appendingPathComponent(listFilename,
                                            isDirectory: false)
            // swiftlint:disable unused_optional_binding
            guard let _ =
                try? dler
                    .copyItem(source: src, destination: dst)
            else {
                return nil
            }
            // swiftlint:enable unused_optional_binding
            return dst
        }
        let src = bundledRules ? fromBundle() : fromContainer()
        guard let source = src else {
            throw ABPKitTestingError.invalidData
        }
        list.source = source.absoluteString
        list.lastVersion = testVersion
        list.name = listName
        list.fileName = listFilename
        return list
    }

    /// Save a given number of test lists to local storage.
    func populateTestModels(count: Int,
                            bundledRules: Bool = true) throws {
        for _ in 1...count {
            guard let testList = try? makeLocalBlockList(bundledRules: bundledRules) else {
                throw ABPKitTestingError.failedModelCreation
            }
            try Persistor().saveFilterListModel(testList)
        }
    }
}
