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

extension ContentBlockerUtility {
    /// Intended to match definitions in
    /// https://gitlab.com/eyeo/adblockplus/abp2blocklist.
    func whiteListRuleForDomain() -> (String) -> BlockingRule {
        return {
            let type = "ignore-previous-rules"
            let urlFilter = ".*"
            return BlockingRule(
                action: Action(selector: nil, type: type),
                trigger: Trigger(
                    ifTopURL: [self.wrappedDomain()($0)],
                    loadType: nil,
                    resourceType: nil,
                    unlessTopURL: nil,
                    urlFilter: urlFilter,
                    urlFilterIsCaseSensitive: false))
        }
    }

    func wrappedDomain() -> (String) -> String {
        return { "^[^:]+:(//)?([^/]+.)?" + $0 + "([^-_.%a-z0-9].*)?$" }
    }
}
