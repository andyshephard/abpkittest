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

import XCTest

class PersistUserModelTests: XCTestCase {
    let rndutil = RandomStateUtility()
    var pstr: Persistor!

    override
    func setUp() {
        super.setUp()
        pstr = Persistor()
    }

    func testUserSave() {
        var user = User(withDefaultValues: true)
        let aae = rndutil.randomState(for: Bool.self)
        let hosts = rndutil.randomState(for: [WhitelistedHostname].self)
        user.acceptableAdsEnabled = aae
        user.whitelistedHosts = hosts
        do {
            let res = try user.save()
            XCTAssert(res == true,
                      "Failed save.")
        } catch let err {
            XCTFail("Error saving: \(err)")
        }
        let saved = try? User(fromPersistentStorage: true)
        XCTAssert(saved?.acceptableAdsEnabled == aae &&
                  saved?.whitelistedHosts == hosts,
                  "Bad user state.")
    }
}
