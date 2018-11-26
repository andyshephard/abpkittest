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
            newEvent.totalBytesWritten = totalBytesWritten
            downloadEvents[taskID]?.onNext(newEvent) // make a new event
        }
    }

    /// A download task has finished downloading. Update the user's block list
    /// metadata and move the downloaded file.
    public
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        let response = downloadTask.response as? HTTPURLResponse
        if !validURLResponse(response) {
            reportError(taskID: taskID, error: .invalidResponse); return
        }
        guard let containerURL = try? Config().containerURL() else {
            reportError(taskID: taskID, error: .badContainerURL); return
        }
        var fname: String!
        if let index = indexForTaskID()(taskID) {
            fname = downloads[index].blockList?.name.addingFileExtension(Constants.rulesExtension)
        } else {
            reportError(taskID: taskID, error: .badFilename); return
            fname = UUID().uuidString.addingFileExtension(Constants.rulesExtension)
        }
        let dst = containerURL
            .appendingPathComponent(fname,
                                    isDirectory: false)
        do {
            try moveOrReplaceItem(source: location,
                                  destination: dst)
        } catch let err {
            let fileError = err as? ABPDownloadTaskError
            if fileError != nil {
                reportError(taskID: taskID, error: fileError!)
            }
        }
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            newEvent.didFinishDownloading = true
            downloadEvents[taskID]?.onNext(newEvent)
        }
    }

    /// A URL session task has finished transferring data.
    /// Download events are updated.
    /// The downloaded data is persisted to local storage.
    public
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let taskID = task.taskIdentifier
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            if error != nil {
                newEvent.error = error
            }
            downloadEvents[taskID]?.onNext(newEvent)
            downloadEvents[taskID]?.onCompleted()
        }
    }

    func indexForTaskID() -> (Int) -> Int? {
        return { tid in
            self.downloads.enumerated().filter { $1.task?.taskIdentifier == tid }.first?.0
        }
    }

    /// Generate a new event and report an error.
    private
    func reportError(taskID: DownloadTaskID,
                     error: ABPDownloadTaskError) {
        if var newEvent = lastDownloadEvent(taskID: taskID) {
            newEvent.error = error
            downloadEvents[taskID]?.onNext(newEvent) // new event
        }
    }
}
