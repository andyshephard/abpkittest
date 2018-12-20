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
    /// Based on [abp2blocklist](https://gitlab.com/eyeo/adblockplus/abp2blocklist).
    func whiteListRuleForDomains() -> ([String]) -> BlockingRule {
        return {
            let actionType = "ignore-previous-rules"
            let loadType = ["first-party", "third-party"]
            let urlFilter = ".*"
            return BlockingRule(
                action: Action(selector: nil, type: actionType),
                trigger: Trigger(
                    ifTopURL: $0.map { self.wrappedDomain()($0) } ,
                    loadType: loadType,
                    resourceType: nil,
                    unlessTopURL: nil,
                    urlFilter: urlFilter,
                    urlFilterIsCaseSensitive: false))
        }
    }

    func whiteListRuleForUser() -> (User) throws -> BlockingRule {
        return { user in
            if let domains = user.whitelistedDomains {
                return self.whiteListRuleForDomains()(domains)
            } else { throw ABPUserModelError.badDataUser }
        }
    }

    func wrappedDomain() -> (String) -> String {
        return { "^[^:]+:(//)?([^/]+\\.)?" + $0 + "([^-_.%%a-z0-9].*)?$" }
    }
}
