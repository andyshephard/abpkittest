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

/// Intermediate metadata container.
struct SourceDownload {
    var task: URLSessionDownloadTask?
    var blockList: BlockList?
    var url: URL?
}

class UserBlockListDownloader: NSObject,
                               URLSessionDownloadDelegate {
    var user: User!
    /// Active downloads for use by delegate - state is not persisted.
    var srcDownloads = [SourceDownload]()
    /// Download events keyed by task ID.
    var downloadEvents = TaskDownloadEvent()
    /// For download tasks.
    var downloadSession: URLSession!

    init(user: User) {
        super.init()
        self.user = user
        downloadSession = newDownloadSession()
    }
}

extension UserBlockListDownloader {
    func newDownloadSession() -> URLSession {
        return URLSession(configuration: URLSessionConfiguration.default,
                          delegate: self,
                          delegateQueue: .main)
    }

    // @todo fix rpt
    /// Return true if the status code is valid.
    func validURLResponse(_ response: HTTPURLResponse?) -> Bool {
        if let uwResponse = response {
            let code = uwResponse.statusCode
            if code >= 200 && code < 300 {
                return true
            }
        }
        return false
    }

    /// Get last event from behavior subject matching the task ID.
    /// - parameter taskID: A background task identifier.
    /// - returns: The download event value if it exists, otherwise nil.
    func lastDownloadEvent(taskID: Int) -> UserDownloadEvent? {
        if let subject = downloadEvents[taskID] {
            if let lastEvent = try? subject.value() {
                return lastEvent
            }
        }
        return nil
    }
}

extension UserBlockListDownloader {
    func downloadForUser(_ user: User) throws {
        srcDownloads = try blockListDownloads()(user)
    }

    /// Cancel all existing downloads.
    /// Create tasks for downloading user's block list and start them.
    func blockListDownloads() -> (User) throws -> [SourceDownload] {
        return { user in
            _ = self.downloadsCancelled()(self.srcDownloads)
            do {
                return try self.sourceDownloads()(user.blockList?.source as? BlockListSourceable & RulesDownloadable)
                    .map { $0.task?.resume(); return $0 }
            } catch let err { throw err }
        }
    }

    /// Cancel all existing downloads.
    func downloadsCancelled() -> ([SourceDownload]) -> [SourceDownload] {
        return { dls in
            dls.map { $0.task?.cancel(); return $0 }
        }
    }

    /// Return SourceDownload collection for a downloadable source.
    func sourceDownloads() -> ((BlockListSourceable & RulesDownloadable)?) throws -> [SourceDownload] {
        return {
            switch $0 {
            case let src where src as? RemoteBlockList != nil:
                return try RemoteBlockList.allCases.map {
                    var srcDL = SourceDownload()
                    srcDL.blockList = try BlockList(withAcceptableAds: $0.hasAcceptableAds(), source: $0)
                    srcDL.url = URL(string: $0.rawValue)
                    if let url = srcDL.url {
                        srcDL.task = self.downloadSession.downloadTask(with: url)
                    } else {
                        throw ABPDownloadTaskError.badSourceURL
                    }
                    return srcDL
                }
            default:
                return []
            }
        }
    }

    /// Return if source is downloadable.
    func isDownloadable() -> ((BlockListSourceable & RulesDownloadable)?) -> Bool {
        return { $0 as? RemoteBlockList != nil }
    }
}
