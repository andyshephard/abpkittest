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

class RandomStateUtility {
    let random = { maxInt in return Int(arc4random_uniform(maxInt + 1)) }

    func randomState<U>(for metatype: U.Type) -> U? {
        if metatype == Bool.self {
            if random(1) == 1 { return true as? U }
            return false as? U
        } else if metatype == Int.self {
            if random(1) == 1 { return 1 as? U }
            return 0 as? U
        } else if metatype == Date.self {
            return Date() +
                TimeInterval(random(10)) *
                Constants.defaultFilterListExpiration as? U
        } else if metatype == [String].self {
            let chars = "abcdefghijklmnopqrstuvwxyz"
            let countMax = random(11)
            var arr = [String]()
            for _ in 0...countMax {
                let idx = chars.index(chars.startIndex,
                                      offsetBy: random(UInt32(chars.count - 1)))
                arr.append(String(chars[idx]))
            }
            return arr as? U
        }
        return nil
    }
}
