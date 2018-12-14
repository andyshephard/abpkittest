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

/// Data sent during downloads of block lists.
public
struct BlockListDownloadData {
    let addonName = "abpkit",
    addonVer = ABPActiveVersions.abpkitVersion() ?? "",
    applicationVer = ABPActiveVersions.osVersion(),
    platform = "webkit",
    platformVer = ABPActiveVersions.webkitVersion() ?? ""
    #if os(iOS)
    let application = ABPPlatform.ios.rawValue
    #elseif os(macOS)
    let application = ABPPlatform.macos.rawValue
    #else
    let application = "unknown"
    #endif
    /// Maximum value beyond which download count is represented by (n-1)+.
    let maxDownloadCount = 5
    public var queryItems: [URLQueryItem]!

    /// A block list download data struct.
    public
    init(user: User) {
        queryItems = [
            URLQueryItem(name: "addonName", value: addonName),
            URLQueryItem(name: "addonVersion", value: addonVer),
            URLQueryItem(name: "application", value: application),
            URLQueryItem(name: "applicationVersion", value: applicationVer),
            URLQueryItem(name: "platform", value: platform),
            URLQueryItem(name: "platformVersion", value: platformVer),
            URLQueryItem(name: "lastVersion", value: "0"),
            URLQueryItem(name: "downloadCount", value: downloadCountString()(user))
        ]
    }
}

extension BlockListDownloadData {
    func downloadCountString() -> (User) -> String {
        return { user in
            if (user.downloadCount ?? 0) > self.maxDownloadCount {
                return String(self.maxDownloadCount - 1) + "+"
            } else {
                return String(user.downloadCount ?? 0)
            }
        }
    }
}
