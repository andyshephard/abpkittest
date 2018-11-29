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

import ABPKit
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
            self.mockUserDLEvents().forEach {
                if $0.error != nil { observer.onError($0.error!) }
                observer.onNext($0)
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
            evt.error = nil
            bytes += Int64.random(in: 10000...100000)
            evt.totalBytesWritten = bytes
            evt.didFinishDownloading = false
            events.append(evt)
        }
        var evtLast = events.last
        evtLast?.didFinishDownloading = true
        events[events.count + expectedErrorOffset - 1].error = expectedError
        if let evt = evtLast { events.append(evt) }
        return events
    }
}
