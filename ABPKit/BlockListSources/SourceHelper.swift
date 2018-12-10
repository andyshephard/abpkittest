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

/// Helpers for handling block list sources.
public
class SourceHelper {
    public let userSourceable: (User) -> BlockListSourceable? = {
        if let blst = $0.getBlockList() { return blst.source }
        return nil
    }

    public
    init() {
        // Intentionally empty.
    }

    public
    func isRemote() -> (BlockListSourceable) -> Bool {
        return { $0 is RemoteBlockList }
    }

    public
    func isBundled() -> (BlockListSourceable) -> Bool {
        return { $0 is BundledBlockList }
    }

    public
    func bundledSourceForAA() -> (Bool) -> BlockListSourceable {
        return {
            switch $0 {
            case true:
                return BundledBlockList.easylistPlusExceptions
            case false:
                return BundledBlockList.easylist
            }
        }
    }

    public
    func remoteSourceForAA() -> (Bool) -> BlockListSourceable {
        return {
            switch $0 {
            case true:
                return RemoteBlockList.easylistPlusExceptions
            case false:
                return RemoteBlockList.easylist
            }
        }
    }
}
