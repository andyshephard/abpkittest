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

// Coding scheme for these custom BlockList types is a string corresponding to:
//     blocklisttype/source
// AcceptableAdsEnableable allows verification of AA states compared to sources.
//
// CaseIterable is defined individually to prevent generic constraint errors.

/// Raw values are filenames in a bundle.
public
enum BundledBlockList: String,
                       BlockListSourceable,
                       CaseIterable {
    public typealias RawValue = String
    case easylist = "easylist_content_blocker.json"
    case easylistPlusExceptions = "easylist+exceptionrules_content_blocker.json"

    public
    func hasAcceptableAds() -> Bool {
        switch self {
        case .easylist:
            return false
        case .easylistPlusExceptions:
            return true
        }
    }
}

public
enum RemoteBlockList: String,
                      BlockListSourceable,
                      CaseIterable,
                      RulesDownloadable {
    public typealias RawValue = String
    case easylist = "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json"
    case easylistPlusExceptions = "https://easylist-downloads.adblockplus.org/easylist+exceptionrules_content_blocker.json"

    public
    func hasAcceptableAds() -> Bool {
        switch self {
        case .easylist:
            return false
        case .easylistPlusExceptions:
            return true
        }
    }
}

public
enum BundledTestingBlockList: String,
                              BlockListSourceable,
                              CaseIterable {
    public typealias RawValue = String
    case testingEasylist = "test_easylist_content_blocker.json"
    case fakeExceptions = "v1 easylist short.json"

    public
    func hasAcceptableAds() -> Bool {
        switch self {
        case .testingEasylist:
            return false
        case .fakeExceptions:
            return true
        }
    }
}
