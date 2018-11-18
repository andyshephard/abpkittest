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

    func testUserSave() throws {
        var user = try User(withDefaultValues: true)
        guard let aae = rndutil.randomState(for: Bool.self) else { XCTFail("Bad state."); return }
        let hosts = rndutil.randomState(for: [WhitelistedHostname].self)
        var src: BlockListSourceable!
        user.acceptableAdsEnabled = aae
        switch aae {
        case true:
            src = BundledBlockList.easylistPlusExceptions
            user.blockList?.source = src
        case false:
            src = BundledBlockList.easylist
            user.blockList?.source = src
        }
        user.whitelistedHosts = hosts
        try user.save()
        let saved = try User(fromPersistentStorage: true,
                             identifier: nil)
        XCTAssert(saved?.acceptableAdsEnabled == aae &&
                  saved?.blockList?.source as? BundledBlockList == src as? BundledBlockList &&
                  saved?.whitelistedHosts == hosts,
                  "Bad user state.")
    }
}
