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

/// User state has one active BlockList. It may be a copy from a cache
/// collection.
public
struct User: Persistable,
             Equatable {
    let name: String
    /// Active block list.
    var blockList: BlockList?
    /// To be synced with rule lists in WKContentRuleListStore.
    var blockListHistory: [BlockList]?
    /// To be synced with local storage.
    var downloads: [BlockList]?
    var whitelistedDomains: [String]?
}

extension User {
    /// Default init: User gets a default block list.
    public
    init() throws {
        name = UUID().uuidString
        blockList = try BlockList(
            withAcceptableAds: true,
            source: BundledBlockList.easylistPlusExceptions)
        blockListHistory = []
        downloads = []
        whitelistedDomains = []
    }

    /// For use during the period where only a single user is supported.
    public
    init?(fromPersistentStorage: Bool,
          persistenceID: String? = nil) throws {
        switch fromPersistentStorage {
        case true:
            try self.init(persistenceID: "ignore_id")
        case false:
            try self.init()
        }
    }

    /// Set the block list during init.
    public
    init?(fromPersistentStorage: Bool,
          withBlockList: BlockList) throws {
        try self.init(fromPersistentStorage: fromPersistentStorage)
        blockList = withBlockList
    }

    /// Only a single user is supported here and identifier is not used.
    /// Multiple user support will be in a future version.
    init?(persistenceID: String) throws {
        let pstr = try Persistor()
        let data = try pstr.load(type: Data.self, key: ABPMutableState.StateName.user)
        self = try pstr.decodeModelData(type: User.self, modelData: data)
        try Persistor().logRulesFiles()
    }
}

// MARK: - Getters -

extension User {
    public
    func getName() -> String {
        return name
    }

    public
    func getBlockList() -> BlockList? {
        return blockList
    }

    public
    func getWhiteListedDomains() -> [String]? {
        return whitelistedDomains
    }

    public
    func getHistory() -> [BlockList]? {
        return blockListHistory
    }

    public
    func getDownloads() -> [BlockList]? {
        return downloads
    }

    func blockListNamed(_ name: String) -> ([BlockList]) throws -> BlockList? {
        return { lists in
            let res = lists.filter { $0.name == name }
            if res.count == 1 { return res.first }
            throw ABPUserModelError.badDataUser
        }
    }

    public
    func acceptableAdsInUse() -> Bool {
        if let blst = blockList,
           let sourceHasAA = try? AcceptableAdsHelper().aaExists()(blst.source) {
            return sourceHasAA
        }
        return false
    }
}

// MARK: - Copiers -

extension User {
    public
    func blockListSet() -> (BlockList) -> User {
        return {
            var copy = self
            copy.blockList = $0
            return copy
        }
    }

    /// Set domains for user's white list.
    public
    func whiteListedDomainsSet() -> ([String]) -> User {
        return {
            var copy = self
            copy.whitelistedDomains = $0
            return copy
        }
    }

    func downloadAdded() -> (BlockList) -> User {
        return {
            var copy = self
            if copy.downloads == nil { copy.downloads = [] }
            var blst = $0
            blst.dateDownload = Date()
            copy.downloads!.append(blst)
            return copy
        }
    }

    /// Adds the current blocklist to history while pruning.
    /// Does not automatically get called.
    /// Should be called when changing the user's rule list.
    func historyUpdated() throws -> User {
        let max = Constants.userBlockListMax
        var copy = self
        guard let blst = copy.blockList else { throw ABPUserModelError.failedUpdateData }
        if copy.blockListHistory == nil { copy.blockListHistory = [] }
        if (copy.blockListHistory!.contains { $0.name == blst.name }) {
            copy.blockListHistory = prunedHistory(max)(copy.blockListHistory!)
        } else {
            copy.blockListHistory = prunedHistory(max)(prunedHistory(max)(copy.blockListHistory!) + [blst])
        }
        return copy
    }

    /// Does not include current block list.
    func downloadsUpdated() throws -> User {
        let max = Constants.userBlockListMax
        var copy = self
        if copy.downloads == nil { copy.downloads = [] }
        copy.downloads = prunedHistory(max)(copy.downloads!)
        return copy
    }

    func updatedBlockList(blockList: BlockList) -> (User) -> User {
        return { var copy = $0; copy.blockList = blockList; return copy }
    }
}

// MARK: - Savers -

extension User {
    public
    func save() throws {
        return try Persistor().saveModel(self, state: .user)
    }

    public
    func saved() throws -> User {
        try Persistor().saveModel(self, state: .user); return self
    }
}

// MARK: - Utility -

extension User {
    private
    func prunedHistory<U: BlockListable>(_ max: Int) -> ([U]) -> [U] {
        return { arr in
            guard arr.count > 0 else { return [] }
            var copy = arr
            if copy.count > max { copy.removeFirst(arr.count - max) }
            return copy
        }
    }
}
