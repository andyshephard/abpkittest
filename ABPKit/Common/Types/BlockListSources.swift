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

protocol AcceptableAdsEnableable {
    func hasAcceptableAds() -> Bool
}

/// Raw values are filenames in a bundle.
public
enum BundledBlockList: String,
                       AcceptableAdsEnableable {
    public typealias RawValue = String
    case easylist = "easylist_content_blocker.json"
    case easylistPlusExceptions = "easylist+exceptionrules_content_blocker"

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
                      AcceptableAdsEnableable {
    public typealias RawValue = String
    case easylist = "https://easylist-downloads.adblockplus.org/easylist_content_blocker.json"
    case easylistPlusExceptions = "https://easylist-downloads.adblockplus.org/easylist+exceptionrules_content_blocker.json"

    func hasAcceptableAds() -> Bool {
        switch self {
        case .easylist:
            return false
        case .easylistPlusExceptions:
            return true
        }
    }
}