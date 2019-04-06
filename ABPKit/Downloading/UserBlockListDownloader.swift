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

/// Handles all downloads for a user. Some user states are persisted based on
/// their initial state.
class UserBlockListDownloader: NSObject,
                               URLSessionDownloadDelegate,
                               Loggable {
    typealias LogType = String

    /// Current user state.
    var user: User!
    /// Active downloads for use by delegate - state is not persisted.
    var srcDownloads = [SourceDownload]()
    /// Download events keyed by task ID.
    var downloadEvents = TaskDownloadEvents()
    /// Serial queue for download session.
    lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = Constants.queueDownloads
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    /// For download tasks.
    lazy var downloadSession: URLSession! = {
        URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: self,
            delegateQueue: downloadQueue)
    }()
    /// For debugging.
    var logWith: ((LogType) -> Void)?

    init(user: User, logWith: ((LogType) -> Void)? = nil) {
        super.init()
        self.user = user
        self.logWith = logWith
    }
}

extension UserBlockListDownloader {
    /// Return true if the status code is valid.
    func validURLResponse(_ response: HTTPURLResponse?) -> Bool {
        return { response?.statusCode }().map { $0 >= 200 && $0 < 300 } ?? false
    }

    /// Get last event from behavior subject matching the task ID.
    /// - parameter taskID: A background task identifier.
    /// - returns: The download event value if it exists, otherwise nil.
    func lastDownloadEvent(taskID: Int) -> UserDownloadEvent? {
        return (downloadEvents[taskID].map { try? $0.value() })?.map { $0 }
    }
}

extension UserBlockListDownloader {
    /// More than one event can have didFinishDownloading == true.
    func userAfterDownloads() -> (Observable<UserDownloadEvent>) -> Observable<User> {
        return {
            $0
                .takeLast(1)
                .filter { $0.didFinishDownloading == true }
                .flatMap { _ -> Observable<User> in
                    return Observable.just(self.userDownloadStateUpdated()(self.user))
                }
        }
    }

    func userDownloadStateUpdated() -> (User) -> User {
        return { user in
            var copy = user
            copy.downloadCount = (copy.downloadCount ?? 0) + 1
            copy.lastVersion = "0" // not currently parsed
            return copy
        }
    }

    /// Update user's block list with most recently downloaded block list.
    func userBlockListUpdated() -> (User) throws -> User {
        return { user in
            let match = try user.downloads?
                .sorted { $0.dateDownload?.compare($1.dateDownload ?? .distantPast) == .orderedDescending }
                .filter { // only allow AA matches if AA enableable
                    if let blst = user.blockList, blst.source is AcceptableAdsEnableable {
                        return try AcceptableAdsHelper().aaExists()($0.source) == AcceptableAdsHelper().aaExists()(blst.source)
                    }
                    return true
                }.first
            if let updated = match.map({ user.updatedBlockList()($0) }) {
                return updated
            }
            throw ABPUserModelError.badDownloads
        }
    }

    func downloadedUserBlockLists() throws -> [BlockList] {
        return try sourcesToBlockLists()(blockListDownloads()(user))
    }

    /// Cancel all existing downloads.
    /// Start tasks after creating tasks for downloading sources in user's block list.
    func blockListDownloads() -> (User) throws -> [SourceDownload] {
        return { user in
            _ = self.downloadsCancelled()(self.srcDownloads)
            do {
                return try self.sourceDownloads()(user.blockList?.source as? BlockListSourceable & RulesDownloadable)
                    .map { $0.task?.resume(); return $0 }
            } catch let err { throw err }
        }
    }

    /// Performs downloading and assigns events.
    /// Return an observable of all concatenated user dl events.
    func userSourceDownloads() -> Observable<UserDownloadEvent> {
        do {
            // Downloader has state dependency on source DLs:
            srcDownloads = try blockListDownloads()(user)
            // Downloader has state dependency on download events:
            downloadEvents = makeDownloadEvents()(srcDownloads)
            return Observable.concat(downloadEvents.map { $1 })
        } catch { return Observable.error(ABPUserModelError.badDownloads) }
    }

    /// Seed events.
    func makeDownloadEvents() -> ([SourceDownload]) -> (TaskDownloadEvents) {
        return {
            Dictionary(uniqueKeysWithValues: $0
                .map { $0.task?.taskIdentifier }
                .compactMap {
                    ($0!, BehaviorSubject<UserDownloadEvent>(value: UserDownloadEvent()))
                })
        }
    }

    /// Transform sources to block lists - for setting user block list caches.
    func sourcesToBlockLists() -> ([SourceDownload]) -> [BlockList] {
        return {
            $0.reduce([]) {
                if let list = $1.blockList { return $0 + [list] }
                return $0
            }
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
                    if let url = self.queryItemsAdded()(URL(string: $0.rawValue)) {
                        return SourceDownload(
                            task: self.downloadSession.downloadTask(with: url),
                            blockList: try BlockList(withAcceptableAds: $0.hasAcceptableAds(), source: $0),
                            url: url)
                    } else {  throw ABPDownloadTaskError.badSourceURL }
                }
            default:
                return []
            }
        }
    }

    func queryItemsAdded() -> (URL?) -> URL? {
        return {
            if let url = $0, var cmps = URLComponents(string: url.absoluteString) {
                cmps.queryItems = BlockListDownloadData(user: self.user).queryItems
                cmps.encodePlusSign()
                return cmps.url
            }
            return nil
        }
    }

    /// Return if source is downloadable.
    func isDownloadable() -> ((BlockListSourceable & RulesDownloadable)?) -> Bool {
        return { $0 as? RemoteBlockList != nil }
    }
}
