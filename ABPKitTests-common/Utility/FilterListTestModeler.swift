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

    /// Make with rules stored in container.
    func makeLocalBlockList() throws -> BlockList {
        let sep = "."
        let fname = UUID().uuidString + sep + Constants.rulesExtension
        var list = try BlockList(withAcceptableAds: false, source: BundledTestingBlockList.testingEasylist)
        let fromBundle: () throws -> URL = {
            let url = self.bundle.url(forResource: self.testBundleFilename, withExtension: "")
            if url != nil { return url! } else { throw ABPFilterListError.missingRules }
        }
        let containerURL = try cfg.containerURL()
        let dst = containerURL.appendingPathComponent(fname, isDirectory: false)
        try BlockListDownloader().copyItem(source: fromBundle(), destination: dst)
        list.filename = fname
        return list
    }

    /// This model object is for testing the delegate with local data.
    /// Returns a model filter list.
    func makeLocalFilterList(bundledRules: Bool = true) throws -> FilterList {
        let sep = "."
        let listName = "📜" + UUID().uuidString
        let listFilename = UUID().uuidString + sep + Constants.rulesExtension
        var list = try FilterList()
        let fromBundle: () -> URL? = {
            self.bundle.url(forResource: self.testBundleFilename, withExtension: "")
        }
        let fromContainer: () throws -> URL? = {
            guard let src = self.bundle.url(forResource: self.testBundleFilename,
                                            withExtension: "")
            else { return nil }
            guard let containerURL = try? self.cfg.containerURL() else { return nil }
            let dst = containerURL.appendingPathComponent(listFilename, isDirectory: false)
            try BlockListDownloader().copyItem(source: src, destination: dst)
            return dst
        }
        let src = bundledRules ? fromBundle() : try fromContainer()
        guard let source = src else { throw ABPKitTestingError.invalidData }
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
            let testList = try makeLocalFilterList(bundledRules: bundledRules)
            try Persistor().saveFilterListModel(testList)
        }
    }
}
