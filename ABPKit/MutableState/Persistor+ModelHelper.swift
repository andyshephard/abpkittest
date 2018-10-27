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
    func saveFilterListModel(_ list: FilterList) throws -> Bool {
        guard let saved = try? loadFilterListModels() else {
            return false
        }
        let newLists =
            replaceFilterListModel(list,
                                   lists: saved)
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
        guard let data =
            try? load(type: Data.self,
                      key: ABPMutableState.LegacyStateName.filterLists)
        else {
            return []
        }
        guard let decoded = try? decodeListsModelsData(data) else {
            throw ABPFilterListError.failedDecoding
        }
        return decoded
    }

    /// Rules file removal should not be attempted on bundled files as it can
    /// falsely report removal under certain conditions.
    func clearFilterListModels() throws {
        let util = ContentBlockerUtility()
        let mgr = FileManager.default
        let models = try? loadFilterListModels()
        let remove: (URL) -> Error? = { url in
            do { try mgr.removeItem(at: url) } catch let err { return err }
            return nil
        }
        /// Custom bundle only used if defined.
        let rulesURL: (FilterList) -> (URL?, Error?) = { model in
            let name = model.name
            if name == nil { return (nil, ABPFilterListError.missingName) }
            do { let url = try util.getRulesURL(for: name!, ignoreBundle: true)
                 return (url, nil)
            } catch let err { return (nil, err) }
        }
        var failed = false
        do {
            try models?.forEach {
                let (url, err) = rulesURL($0)
                if err != nil {
                    throw err!
                }
                // If the rules are bundled, a remove should not happen below.
                if url != nil {
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
        } catch let err {
            throw err
        }
        if !failed {
            // swiftlint:disable unused_optional_binding
            guard let _ = try? clear(key: ABPMutableState.LegacyStateName.filterLists) else {
                throw ABPMutableStateError.failedClear
            }
            // swiftlint:enable unused_optional_binding
        } else {
            throw ABPFilterListError.failedRemoveModels
        }
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
                                lists: [FilterList]) -> [FilterList] {
        var newLists = [list]
        var replaceCount = 0
        lists.forEach {
            if $0.name == list.name {
                replaceCount += 1
            } else {
                newLists.append($0)
            }
        }
        return newLists
    }
}
