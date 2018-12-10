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

extension SourceHelper {
    /// Return if a source matches another source.
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
        case let src where src as? RemoteBlockList == .easylist:
            return src2 as? RemoteBlockList == .easylist
        case let src where src as? RemoteBlockList == .easylistPlusExceptions:
            return src2 as? RemoteBlockList == .easylistPlusExceptions
        default:
            return false
        }
    }
}
