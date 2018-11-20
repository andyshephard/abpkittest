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

public
class UserStateHelper {
    var user: User!

    public
    init(user: User) {
        self.user = user
    }

    /// Does not verify uniqueness.
    public
    func historyMatch() throws -> (BlockListSourceable) throws -> BlockList? {
        guard let hist = user.blockListHistory else { throw ABPUserModelError.badDataUser }
        return { src in
            return
                hist
                    .filter { self.matchSources(src1: src, src2: $0.source) }
                    .count >= 1
                ? hist.first : nil
        }
    }

    private
    func matchSources(src1: BlockListSourceable,
                      src2: BlockListSourceable) -> Bool {
        switch src1 {
        case let src where src as? BundledBlockList == .easylist:
            return src2 as? BundledBlockList == .easylist
        case let src where src as? BundledBlockList == .easylistPlusExceptions:
            return src2 as? BundledBlockList == .easylistPlusExceptions
        case let src where src as? BundledTestingBlockList == .testingEasylist:
            return src2 as? BundledTestingBlockList == .testingEasylist
        case let src where src as? BundledTestingBlockList == .fakeExceptions:
            return src2 as? BundledTestingBlockList == .fakeExceptions
        default:
            return false
        }
    }

    public
    func clearBlockListHistory() throws {
        user.blockListHistory = []
        try user.save()
    }
}
