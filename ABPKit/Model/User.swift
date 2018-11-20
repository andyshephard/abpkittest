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

/// User has one BlockList active at a time.
/// It may be a copy from the download collection.
public
struct User: Persistable {
    let name: String?
    /// Active block list.
    var blockList: BlockList?
    /// To be synced with rule lists in WKContentRuleListStore.
    public var blockListHistory: [BlockList]?
    /// To be synced with local storage.
    var downloads: [BlockList]?
    var whitelistedDomains: [WhitelistedHostname]?
}

extension User {
    public
    init() throws {
        name = UUID().uuidString
        blockList = try BlockList(withAcceptableAds: true,
                                  source: BundledBlockList.easylistPlusExceptions)
        blockListHistory = []
        downloads = []
        whitelistedDomains = []
    }

    /// For use during the period where only a single user is supported.
    public
    init?(fromPersistentStorage: Bool, persistenceID: String? = nil) throws {
        switch fromPersistentStorage {
        case true:
            try self.init(persistenceID: "ignore_id")
        case false:
            try self.init()
        }
    }

    /// Only a single user is supported here and identifier is not used.
    /// Multiple user support will be in a future version.
    init?(persistenceID: String) throws {
        let pstr = try Persistor()
        let data = try pstr.load(type: Data.self,
                                 key: ABPMutableState.StateName.user)
        self = try pstr.decodeModelData(type: User.self, modelData: data)
        try Persistor().logRulesFiles()
    }
}

extension User {
    public mutating
    func setBlockList(_ blockList: BlockList) {
        self.blockList = blockList
    }

    /// Adds the blocklist to history while pruning.
    /// Does not automatically get called.
    /// Should be called when changing the user's rule list.
    /// Performs a save.
    public mutating
    func updateHistory() throws {
        guard let blst = blockList else { throw ABPUserModelError.failedUpdateData }
        if blockListHistory == nil { blockListHistory = [] }
        if (blockListHistory!.contains { $0.name == blst.name }) {
            blockListHistory = prunedHistory()(blockListHistory!)
        } else {
            // swiftlint:disable operator_usage_whitespace
            blockListHistory =  prunedHistory()(prunedHistory()(blockListHistory!) + [blst])
            // swiftlint:enable operator_usage_whitespace
        }
        try save()
    }

    func prunedHistory() -> ([BlockList]) -> [BlockList] {
        return { hist in
            guard hist.count > 0 else { return [] }
            var copy = hist
            if copy.count > Constants.userHistoryBlockListMax {
                copy.removeFirst(hist.count - Constants.userHistoryBlockListMax)
            }
            return copy
        }
    }
}

extension User {
    public
    func save() throws {
        return try Persistor().saveModel(self, state: .user)
    }

    public
    func blockListNamed(_ name: String) -> ([BlockList]) throws -> BlockList? {
        return { lists in
            let res = lists.filter { $0.name == name }
            if res.count == 1 { return res.first }
            throw ABPUserModelError.badDataUser
        }
    }

    public
    func acceptableAdsInUse() -> Bool {
        return blockList?.source.hasAcceptableAds() ?? false
    }
}
