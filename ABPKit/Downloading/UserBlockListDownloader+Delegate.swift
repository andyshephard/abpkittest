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
    public
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            newEvent.didFinishDownloading = false
            newEvent.totalBytesWritten = totalBytesWritten
            downloadEvents[taskID]?.onNext(newEvent)
        }
    }

    // swiftlint:disable opening_brace
    /// A download task has finished downloading. Update the user's block list
    /// metadata and move the downloaded file. Updates user state.
    public
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        if !validURLResponse(downloadTask.response as? HTTPURLResponse) {
            reportError(taskID: taskID, error: .invalidResponse); return
        }
        guard let containerURL = try? Config().containerURL() else {
            reportError(taskID: taskID, error: .badContainerURL); return
        }
        let index = indexForTaskID()(taskID)
        var fname: String!
        if index != nil {
            fname = srcDownloads[index!].blockList?.name.addingFileExtension(Constants.rulesExtension)
        } else {
            reportError(taskID: taskID, error: .badFilename); return
            fname = UUID().uuidString.addingFileExtension(Constants.rulesExtension) // save it anyway
        }
        let dst = containerURL
            .appendingPathComponent(fname, isDirectory: false)
        do {
            try moveOrReplaceItem(source: location, destination: dst)
        } catch let err {
            { if let fErr = $0 as? ABPDownloadTaskError { self.reportError(taskID: taskID, error: fErr) } }(err)
        }
        if index != nil {
            do {
                if let srcBL = srcDownloads[index!].blockList {
                    self.user = try self.user.downloadAdded()( // only AA enableable sources succeed
                        BlockList(
                            withAcceptableAds: AcceptableAdsHelper().aaExists()(srcBL.source),
                            source: srcBL.source,
                            name: srcBL.name,
                            dateDownload: Date()))
                    try self.user.save() // state updated
                }
            } catch { reportError(taskID: taskID, error: ABPDownloadTaskError.failedToUpdateUserDownloads) }
        }
    }
    // swiftlint:enable opening_brace

    /// A URL session task has finished transferring data.
    /// Download events are updated.
    /// The downloaded data is persisted to local storage.
    public
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let taskID = task.taskIdentifier
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            newEvent.didFinishDownloading = true
            if error != nil { newEvent.error = error }
            downloadEvents[taskID]?.onNext(newEvent)
            downloadEvents[taskID]?.onCompleted()
        }
    }

    func indexForTaskID() -> (Int) -> Int? {
        return { tid in
            self.srcDownloads.enumerated().filter { $1.task?.taskIdentifier == tid }.first?.0
        }
    }

    /// Generate a new event and report an error.
    private
    func reportError(taskID: DownloadTaskID,
                     error: ABPDownloadTaskError) {
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            newEvent.error = error
            downloadEvents[taskID]?.onNext(newEvent)
            downloadEvents[taskID]?.onError(error)
        }
    }
}
