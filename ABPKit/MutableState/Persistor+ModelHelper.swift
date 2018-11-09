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

import RxSwift

// Helper operations for filter lists models in persistence storage:
// * save
// * load
// * clear
extension Persistor {
    /// Return true if save succeeded.
    public
    func saveFilterListModel(_ list: FilterList) throws -> Bool {
        var saved = [FilterList]()
        do {
            saved = try loadFilterListModels()
        } catch let err {
            if let casted = err as? ABPMutableStateError,
               casted == .invalidType { // indicates type not defined yet, can ignore in production
                // ignore it
            } else {
                throw err
            }
        }
        var newLists = [FilterList]()
        do {
            newLists = try replaceFilterListModel(list, lists: saved)
        } catch let err {
            throw err
        }
        guard let data =
            try? PropertyListEncoder()
                .encode(newLists)
        else {
            throw ABPFilterListError.failedEncoding
        }
        // swiftlint:disable unused_optional_binding
        guard let _ =
            try? save(type: Data.self,
                      value: data,
                      key: ABPMutableState.LegacyStateName.filterLists)
        else {
            return false
        }
        // swiftlint:enable unused_optional_binding
        return true
    }

    func loadFilterListModels() throws -> [FilterList] {
        var modelData: Data?
        do {
            modelData = try load(type: Data.self,
                                 key: ABPMutableState.LegacyStateName.filterLists)
        } catch let err {
            throw err
        }
        guard let data = modelData,
              let decoded = try? decodeListsModelsData(data) else {
            throw ABPFilterListError.failedDecoding
        }
        return decoded
    }

    /// Clears filter list models and their associated rules, if they exist.
    /// Rules file removal should not be attempted on bundled files as it can
    /// falsely report removal under certain conditions.
    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    func clearFilterListModels() throws {
        let mgr = FileManager.default
        var models = [FilterList]()
        do {
            models = try loadFilterListModels()
        } catch let err {
            if let casted = err as? ABPMutableStateError,
               casted == .invalidType {
                 // indicates type not defined yet
            } else {
                throw err
            }
        }
        // Remove associated rules:
        let remove: (URL) -> Error? = { url in
            do { try mgr.removeItem(at: url) } catch let err { return err }
            return nil
        }
        /// Custom bundle only used if defined.
        let rulesURL: (FilterList) -> (URL?, Error?) = { model in
            let name = model.name
            if name == nil { return (nil, ABPFilterListError.missingName) }
            do { let url = try model.rulesURL()
                 return (url, nil)
            } catch let err { return (nil, err) }
        }
        var failed = false
        // Remove associated rules by their URL:
        do {
            try models.forEach {
                let (url, err) = rulesURL($0)
                if err != nil {
                    throw err!
                }
                // If the rules are bundled, a remove should not happen below.
                if url != nil {
                    // With Xcode 10.1, attempting removal from bundled
                    // resources is an error.
                    if !blocklistIsLocal(url: url!) {
                        let rmvError = remove(url!)
                        if rmvError != nil {
                            throw rmvError!
                        }
                        // Double check the file has been removed:
                        if mgr.fileExists(atPath: url!.path) {
                            failed = true
                        }
                    }
                }
            }
        } catch let err {
            throw err
        }
        // Removing rules using setobject nil or remove obj on defaults seems to
        // not have reported a correct count here during testing.
        if !failed {
            // swiftlint:disable unused_optional_binding
            guard let _ = try? clear(key: ABPMutableState.LegacyStateName.filterLists) else {
                throw ABPMutableStateError.failedClear
            }
            // swiftlint:enable unused_optional_binding
            guard let data =
                try? PropertyListEncoder()
                    .encode([FilterList]())
            else {
                throw ABPFilterListError.failedEncoding
            }
            // swiftlint:disable unused_optional_binding
            guard let _ =
                try? save(type: Data.self,
                          value: data,
                          key: ABPMutableState.LegacyStateName.filterLists)
            else {
                throw ABPFilterListError.failedRemoveModels
            }
            do {
                models = try loadFilterListModels()
            } catch let error {
                if let casted = error as? ABPMutableStateError,
                   casted == .invalidType {
                    // indicates type not defined yet, ignore for now
                } else {
                    throw error
                }
            }
            if models.count > 0 {
                throw ABPFilterListError.failedRemoveModels
            }
        } else {
            throw ABPFilterListError.failedRemoveModels
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

    private
    func blocklistIsLocal(url: URL) -> Bool {
        let locals = Set([Constants.abpkitDir,
                          Constants.abpkitResourcesDir])
        return Set(url.pathComponents)
            .intersection(locals) == locals
    }

    private
    func decodeListsModelsData(_ listsData: Data) throws -> [FilterList] {
        guard let decoded =
            try? PropertyListDecoder()
                .decode([FilterList].self,
                        from: listsData)
        else {
            throw ABPFilterListError.badData
        }
        return decoded
    }

    /// Intended to prevent duplication of lists.
    private
    func replaceFilterListModel(_ list: FilterList,
                                lists: [FilterList]) throws -> [FilterList] {
        var replaced = 0
        return try lists
            .filter {
                if $0.name == list.name {
                    replaced += 1
                    return false
                }
                return true
            }
            .reduce([list]) {
                if replaced > 1 { throw ABPFilterListError.ambiguousModels }
                return $0 + [$1]
            }
    }
}
