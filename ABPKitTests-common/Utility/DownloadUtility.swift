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

@testable import ABPKit

import RxSwift
import XCTest

class DownloadUtility {
    /// Perform downloads for a user's block list source. Persists user state
    /// after downloads. Reports beginning state on completion.
    func downloadForUser(_ lastUser: (Bool) -> User?,
                         afterDownloadTest: (() -> Void)? = nil,
                         afterUserSavedTest: ((User) -> Void)? = nil,
                         withCompleted: (() -> Void)? = nil) -> Disposable {
        guard let start = lastUser(true) else {
            XCTFail("Bad user."); return Disposables.create()
        }
        let dler = UserBlockListDownloader(user: start)
        return dler.userAfterDownloads()(dler.userSourceDownloads())
            .subscribe(onNext: { user in
                afterDownloadTest?()
                do {
                    try user.save()
                } catch let err { XCTFail("Error: \(err)") }
                afterUserSavedTest?(user)
            }, onError: { err in
                XCTFail("Error: \(err)")
            }, onCompleted: {
                log("👩‍🎤started with DLs #\(start.downloads?.count as Int?) - \(start.downloads as [BlockList]?)")
                withCompleted?()
            })
    }

    /// Make a block list model for a downloadable source.
    func blockListForSource() -> (BlockListSourceable & RulesDownloadable) throws -> BlockList {
        return {
            return try BlockList(withAcceptableAds: $0.hasAcceptableAds(), source: $0)
        }
    }
}
