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

import SafariServices
import XCTest

class ContentBlockerTests: XCTestCase {
    let timeout: TimeInterval = 15

    func testContentBlockerReload() {
        let expect = expectation(description: #function)
        guard let cbid = Config().contentBlockerIdentifier(platform: .macos) else {
            XCTFail("Bad content blocker ID.")
            return
        }
        SFContentBlockerManager
            .reloadContentBlocker(withIdentifier: cbid) { err in
                if err != nil {
                    XCTFail("Failed with error: \(String(describing: err))")
                } else {
                    NSLog("✅ reload succeeded")
                }
                expect.fulfill()
            }
        wait(for: [expect],
             timeout: timeout)
    }
}
