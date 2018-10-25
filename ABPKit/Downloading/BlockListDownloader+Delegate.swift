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

// Implements URLSessionDownloadDelegate functions for the BlockListDownloader.
extension BlockListDownloader {
    /// A URL session task is transferring data.
    public
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let identifier = UIBackgroundTaskIdentifier(rawValue: downloadTask.taskIdentifier)
        if var newEvent = lastDownloadEvent(taskID: identifier) {
            newEvent.totalBytesWritten = totalBytesWritten
            downloadEvents[identifier]?.onNext(newEvent) // make a new event
        }
    }

    /// A download task for a filter list has finished downloading. Update the user's filter list
    /// metadata and move the downloaded file. Future optimization can include retrying the
    /// post-download operations if an error is encountered.
    public
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let taskInt = downloadTask.taskIdentifier
        let taskIdentifier = UIBackgroundTaskIdentifier(rawValue: taskInt)
        guard let name = try? filterListName(for: taskInt) else {
            reportError(identifier: taskInt, error: .badFilterListModelName); return
        }
        guard let result = try? filterList(withName: name),
              var list = result
        else {
            reportError(identifier: taskInt, error: .badFilterListModel); return
        }
        let response = downloadTask.response as? HTTPURLResponse
        if !validURLResponse(response) {
            reportError(identifier: taskInt, error: .invalidResponse); return
        }
        guard let containerURL = try? cfg.containerURL() else {
            reportError(identifier: taskInt, error: .badContainerURL); return
        }
        guard let fileName = list.fileName else {
            reportError(identifier: taskInt, error: .badFilename); return
        }
        let destination =
            containerURL
                .appendingPathComponent(fileName,
                                        isDirectory: false)
        do {
            try moveOrReplaceItem(source: location,
                                  destination: destination)
        } catch let error {
            let fileError = error as? ABPDownloadTaskError
            if fileError != nil {
                reportError(identifier: taskInt, error: fileError!)
            }
        }
        list = downloadedModelState(list: list)
        downloadedVersion += 1
        if var newEvent = lastDownloadEvent(taskID: taskIdentifier) {
            newEvent.didFinishDownloading = true
            downloadEvents[taskIdentifier]?.onNext(newEvent) // new event
        }
        AppExtensionRelay.sharedInstance().downloadedVersion.accept(downloadedVersion)
        guard let saveResult = try? pstr.saveFilterListModel(list),
              saveResult == true
        else {
            reportError(identifier: taskInt, error: .failedFilterListModelSave); return
        }
    }

    /// A URL session task has finished transferring data.
    /// Download events are updated.
    /// The downloaded data is persisted to local storage.
    public
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let taskInt = task.taskIdentifier
        let taskIdentifier = UIBackgroundTaskIdentifier(rawValue: taskInt)
        guard let name = try? filterListName(for: taskInt)
        else {
            reportError(identifier: taskInt, error: .badFilterListModelName); return
        }
        guard let result = try? filterList(withName: name),
              var list = result
        else {
            reportError(identifier: taskInt, error: .badFilterListModel); return
        }
        list.lastUpdateFailed = true
        list.updating = false
        list.taskIdentifier = nil
        guard let saveResult = try? pstr.saveFilterListModel(list),
              saveResult == true
        else {
            reportError(identifier: taskInt, error: .failedFilterListModelSave); return
        }
        downloadTasksByID[taskIdentifier] = nil
        if var newEvent = lastDownloadEvent(taskID: taskIdentifier) {
            if error != nil {
                newEvent.error = error
            }
            newEvent.errorWritten = true
            downloadEvents[taskIdentifier]?.onNext(newEvent)
            downloadEvents[taskIdentifier]?.onCompleted()
        }
    }

    /// Set state of list that is downloaded.
    private
    func downloadedModelState(list: FilterList) -> FilterList {
        var mutable = list
        mutable.lastUpdate = Date()
        mutable.downloaded = true
        mutable.lastUpdateFailed = false
        mutable.updating = false
        return mutable
    }

    /// Generate a new event and report an error.
    private
    func reportError(identifier: Int,
                     error: ABPDownloadTaskError) {
        let taskIdentifier = UIBackgroundTaskIdentifier(rawValue: identifier)
        if var newEvent = lastDownloadEvent(taskID: taskIdentifier) {
            newEvent.error = error
            newEvent.errorWritten = true
            downloadEvents[taskIdentifier]?.onNext(newEvent) // new event
        }
    }
}
