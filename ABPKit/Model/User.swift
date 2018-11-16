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
struct User: Persistable {
    var name: String?
    var acceptableAdsEnabled: Bool?
    var blockList: BlockList?
    var whitelistedHosts: [WhitelistedHostname]?

    init(withDefaultValues: Bool) throws {
        if withDefaultValues {
            self.name = UUID().uuidString
            acceptableAdsEnabled = true
            blockList = try BlockList(withAcceptableAds: true,
                                      source: BundledBlockList.easylistPlusExceptions)
            whitelistedHosts = []
        }
    }

    /// Only a single user is supported here and identifier is not used.
    /// Multiple user support will be in a future version.
    init?(fromPersistentStorage: Bool,
          identifier: String?) throws {
        guard fromPersistentStorage else { try self.init(withDefaultValues: true); return }
        guard let pstr = Persistor() else { throw ABPMutableStateError.missingDefaults }
        let data = try pstr.load(type: Data.self,
                                 key: ABPMutableState.StateName.user)
        try self.init(withDefaultValues: false)
        self = try pstr.decodeModelData(type: User.self, modelData: data)
    }
}

extension User {
    public
    func save() throws -> Bool {
        return try Persistor()?.saveModel(self, state: .user) ?? false
    }
}
