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

extension UserBlockListDownloader {
    /// A URL session task is transferring data.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        downloadEvents[taskID]?.onNext(
            UserDownloadEvent(
                withNotFinishedEvent: lastDownloadEvent(taskID: taskID),
                bytesWritten: totalBytesWritten))
    }

    /// A download task has finished downloading. Update the user's block list
    /// metadata and move the downloaded file. Updates user state.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        if !validURLResponse(downloadTask.response as? HTTPURLResponse) {
            reportError(ABPDownloadTaskError.invalidResponse, taskID: taskID); return
        }
        let idx = indexForTaskID()(taskID)
        if let fname = (idx.map {
            srcDownloads[$0]
        }.map {
            $0.blockList?.name.addingFileExtension(Constants.rulesExtension)
        })?.map({ $0 }) {
            do {
                try moveOrReplaceItem(
                    source: location,
                    destination: try Config().containerURL()
                        .appendingPathComponent(fname, isDirectory: false))
                if let srcBL = (idx.map { srcDownloads[$0].blockList })?.map({ $0 }) {
                    self.user = try self.user.downloadAdded()( // only AA enableable sources succeed
                        BlockList(
                            withAcceptableAds: AcceptableAdsHelper().aaExists()(srcBL.source),
                            source: srcBL.source,
                            name: srcBL.name,
                            dateDownload: Date())).saved()
                }
            } catch let err { self.reportError(err, taskID: taskID) }
        } else { reportError(ABPDownloadTaskError.badFilename, taskID: taskID) }
    }

    /// A URL session task has finished transferring data.
    /// Download events are updated.
    /// The downloaded data is persisted to local storage.
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let taskID = task.taskIdentifier
        downloadEvents[taskID]?.onNext(
            UserDownloadEvent(
                finishWithEvent: lastDownloadEvent(taskID: taskID)))
        if error != nil { reportError(error!, taskID: taskID) }
        downloadEvents[taskID]?.onCompleted()
    }

    func indexForTaskID() -> (Int) -> Int? {
        return { tid in
            self.srcDownloads.enumerated().filter { $1.task?.taskIdentifier == tid }.first?.0
        }
    }

    /// Report an error.
    private
    func reportError(_ error: Error,
                     taskID: DownloadTaskID) {
        downloadEvents[taskID]?.onError(error)
    }
}
