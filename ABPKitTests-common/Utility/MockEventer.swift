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

class MockEventer {
    let expectedEvents = Int.random(in: 10...30)
    let expectedErrorOffset = -1 * Int.random(in: 1...9)
    let expectedError: Error!

    init(error: Error) {
        expectedError = error
    }

    func mockObservable() -> Observable<UserDownloadEvent> {
        return Observable.create { observer in
            for (idx, evt) in self.mockUserDLEvents().enumerated() {
                if idx != self.mockUserDLEvents().count + self.expectedErrorOffset - 1 {
                    observer.onNext(evt)
                } else { observer.onError(self.expectedError) }
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }

    private
    func mockUserDLEvents() -> [UserDownloadEvent] {
        var events = [UserDownloadEvent]()
        var bytes: Int64 = 0
        var evt = UserDownloadEvent()
        for _ in 1...expectedEvents {
            bytes += Int64.random(in: 10000...100000)
            evt.totalBytesWritten = bytes
            evt.didFinishDownloading = false
            events.append(evt)
        }
        var evtLast = events.last
        evtLast?.didFinishDownloading = true
        if evtLast != nil { events.append(evtLast!) }
        return events
    }
}
