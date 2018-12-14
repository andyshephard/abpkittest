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

    /// Return a BL in user history that matches a given source.
    func historyMatch() throws -> (BlockListSourceable) throws -> BlockList? {
        guard let hist = user.blockListHistory else { throw ABPUserModelError.badDataUser }
        return { try self.blockListsMatch(hist)($0) }
    }

    /// Return a DL in user downloads that matches a given source.
    public
    func downloadsMatch() throws -> (BlockListSourceable) throws -> BlockList? {
        guard let dls = user.downloads else { throw ABPUserModelError.badDataUser }
        return { try self.blockListsMatch(dls)($0) }
    }

    func clearBlockListHistory() throws {
        user.blockListHistory = []
        try user.save()
    }

    /// Return a blocklist in a set of lists that matches a given source.
    /// Does not verify uniqueness.
    private
    func blockListsMatch(_ lists: [BlockList]) throws -> (BlockListSourceable) throws -> BlockList? {
        return { src in
            return
                lists
                    .filter { SourceHelper().matchSources(src1: src, src2: $0.source) }
                    .first
        }
    }
}
