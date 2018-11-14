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
struct User: Codable {
    var acceptableAdsEnabled: Bool?
    var whitelistedHosts: [WhitelistedHostname]?

    init(withDefaultValues: Bool) {
        if withDefaultValues {
            acceptableAdsEnabled = false
            whitelistedHosts = []
        }
    }

    init(fromPersistentStorage: Bool) throws {
        guard fromPersistentStorage else { self.init(withDefaultValues: true); return }
        guard let pstr = Persistor() else { throw ABPMutableStateError.missingDefaults }
        var modelData: Data?
        do {
            modelData = try pstr.load(type: Data.self,
                                      key: ABPMutableState.StateName.user)
        } catch let err {
            throw err
        }
        self.init(withDefaultValues: false)
        guard let data = modelData,
              let decoded = try? decodeUserModelData(data)
        else {
            throw ABPUserModelError.failedDecodingUser
        }
        self = decoded
    }
}

extension User {
    public
    func save() throws -> Bool {
        guard let pstr = Persistor() else { throw ABPMutableStateError.missingDefaults }
        var data: Data?
        do {
            data = try self.encode()
        } catch let err {
            throw err
        }
        // swiftlint:disable unused_optional_binding
        guard let uwData = data,
              let _ =
            try? pstr.save(type: Data.self,
                           value: uwData,
                           key: ABPMutableState.StateName.user)
        else {
            return false
        }
        // swiftlint:enable unused_optional_binding
        return true
    }

    private
    func encode() throws -> Data {
        guard let data =
            try? PropertyListEncoder()
                .encode(self)
        else {
            throw ABPUserModelError.failedEncodingUser
        }
        return data
    }

    private
    func decodeUserModelData(_ userData: Data) throws -> User {
        guard let decoded =
            try? PropertyListDecoder()
                .decode(User.self,
                        from: userData)
            else {
                throw ABPUserModelError.badDataUser
        }
        return decoded
    }
}
