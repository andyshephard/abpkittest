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

import Foundation

/// Swift-based FilterList model struct to replace the Objective-C FilterList model object. This
/// is used internally to represent filter lists.
///
/// Some legacy properties exist but will be removed in future versions.
public
struct FilterList: Codable {
    /// Counter for number of successful downloads.
    public var downloadCount: Int?

    /// Name used to identify a list uniquely.
    public var name: FilterListName?

    /// The last version value extracted from the filter list or default value of "0".
    public var lastVersion: FilterListLastVersion = "0"

    /// Task identifier of the associated download task.
    public var taskIdentifier: Int?

    /// Group identifier refer to an associated download group. Only download tasks triggered by a
    /// user are allowed to display download failure dialogs. The updatingGroupIdentifier
    /// represents the group of the most recent download tasks.
    public var updatingGroupIdentifier: Int?

    public var downloaded: Bool?
    public var expires: TimeInterval?
    public var fileName: String?
    public var lastUpdate: Date?
    /// Legacy property.
    public var lastUpdateFailed: Bool?
    /// Legacy property.
    public var updating: Bool?
    /// Original download location as a URL string.
    public var source: String?
    /// Legacy property.
    public var userTriggered: Bool?
    public var version: String?

    public
    init() {
        // Intentionally empty
    }
}

extension FilterList {
    /// Return URL for local content blocking rules, the JSON file.
    public
    func rulesURL(bundle: Bundle = Config().bundle(),
                  ignoreBundle: Bool = false) throws -> URL? {
        guard let pstr = Persistor() else {
            throw ABPMutableStateError.missingDefaults
        }
        guard let modelName = name else {
            throw ABPFilterListError.missingName
        }
        let lists = try? pstr.loadFilterListModels()
        var fname: String?
        var cnt = 0
        lists?.forEach {
            if $0.name == modelName {
                fname = $0.fileName
                cnt += 1
            }
        }
        if cnt == 0 {
            throw ABPFilterListError.notFound
        } else if cnt != 0 && cnt != 1 {
            throw ABPFilterListError.ambiguousModels
        }
        let url = try? Config().containerURL()
        let mgr = FileManager.default
        let pathURL = fname != nil ? url?.appendingPathComponent(fname!) : nil
        let result = pathURL != nil ? mgr.fileExists(atPath: pathURL!.path) : false
        if result {
            return pathURL
        }
        // If URL not found in the container, look in the bundle:
        let cbutil = ContentBlockerUtility()
        if !ignoreBundle,
            let url =
                try? cbutil
                    .getBundledFilterListFileURL(name: modelName,
                                                 bundle: bundle) {
            return url
        }
        return nil
    }

    /// This is not using an expiration interval from a v2 filter list as that data is not yet available.
    /// - Returns: True if the filter list is considered to be expired.
    public
    func expired() -> Bool {
        let nowInterval = Date.timeIntervalSinceReferenceDate
        if expires == nil && lastUpdate != nil {
            // Default to a fixed expiration.
            let defaultIntervalPlusLast =
                lastUpdate!.addingTimeInterval(Constants.defaultFilterListExpiration)
                    .timeIntervalSinceReferenceDate
            return defaultIntervalPlusLast < nowInterval
        } else if expires != nil && lastUpdate != nil {
            return expires! < nowInterval
        } else {
            // Expires is nil and last update is nil.
            return true
        }
    }
}
