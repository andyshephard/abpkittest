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

import RxSwift

public typealias AppGroupName = String
public typealias AppGroupContainerURL = URL
public typealias BlockListData = Data
public typealias BlockListDirectoryURL = URL
public typealias BlockListFilename = String
public typealias BlockListFileURL = URL
public typealias BundleName = String
public typealias BundlePrefix = String
public typealias ContentBlockerIdentifier = String
public typealias DefaultsSuiteName = String
public typealias DownloadEventID = String
public typealias DownloadTaskID = Int
public typealias FilterListFileURL = URL
public typealias FilterListID = String
public typealias FilterListLastVersion = String
public typealias FilterListName = String
public typealias FilterListV2Sources = [[String: String]]
public typealias LegacyFilterLists = [String: [String: Any]]
public typealias NamedErrors = [String: Error]
public typealias RulesStoreFileURL = URL
public typealias TaskDownloadEvents = [Int: BehaviorSubject<UserDownloadEvent>]
public typealias WhitelistedHostname = String
public typealias WhitelistedWebsites = [String]
