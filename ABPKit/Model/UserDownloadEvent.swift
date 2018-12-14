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

/// Represents the changing state of a download.
public
struct UserDownloadEvent {
    public var didFinishDownloading: Bool?
    public var totalBytesWritten: Int64?
    public var error: Error?

    public
    init(didFinishDownloading: Bool?,
         totalBytesWritten: Int64?,
         error: Error?) {
        self.didFinishDownloading = didFinishDownloading
        self.totalBytesWritten = totalBytesWritten
        self.error = error
    }

    public
    init() {
        self.init(
            didFinishDownloading: nil,
            totalBytesWritten: nil,
            error: nil)
    }
}
