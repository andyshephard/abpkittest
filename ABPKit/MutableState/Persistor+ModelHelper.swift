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
    /// Save and replace, if needed.
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
        // swiftlint:disable unused_optional_binding
        guard let _ =
            try? save(type: Data.self,
                      value: encodeModel(newLists),
                      key: ABPMutableState.StateName.filterLists)
        else {
            return false
        }
        // swiftlint:enable unused_optional_binding
        return true
    }

    func loadFilterListModels() throws -> [FilterList] {
        return try loadModels(type: [FilterList].self,
                              state: .filterLists)
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
                    if try !blocklistIsBundled(url: url!) {
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
            guard let _ = try? clear(key: ABPMutableState.StateName.filterLists) else {
                throw ABPMutableStateError.failedClear
            }
            guard let data =
                try? encodeModel([FilterList]())
            else {
                throw ABPFilterListError.failedEncoding
            }
            guard let _ =
                try? save(type: Data.self,
                          value: data,
                          key: ABPMutableState.StateName.filterLists)
            else {
                throw ABPFilterListError.failedRemoveModels
            }
            // swiftlint:enable unused_optional_binding
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

    func loadModels<T: Decodable>(type: T.Type,
                                  state: ABPMutableState.StateName) throws -> T {
        return try decodeModelData(type: T.self,
                                   modelData: load(type: Data.self,
                                                   key: state))
    }

    func decodeModelData<T: Decodable>(type: T.Type,
                                       modelData: Data) throws -> T {
        return try PropertyListDecoder().decode(T.self,
                                                from: modelData)
    }

    func saveModel<T: Encodable>(_ model: T,
                                 state: ABPMutableState.StateName) throws -> Bool {
        // swiftlint:disable unused_optional_binding
        guard let _ = try? save(type: Data.self,
                                value: encodeModel(model),
                                key: state)
        else {
            return false
        }
        // swiftlint:enable unused_optional_binding
        return true
    }

    func encodeModel<T: Encodable>(_ model: T) throws -> Data {
        return try PropertyListEncoder().encode(model)
    }

    /// Determines if a file is part of the bundle. Since the framework name +
    /// extension is used, that path component shouldn't appear outside of a
    /// context involving bundled resources.
    private
    func blocklistIsBundled(url: URL) throws -> Bool {
        #if os(macOS)
        let bundleComps = Set([Constants.abpkitDir,
                               Constants.abpkitResourcesDir])
        #elseif os(iOS)
        let bundleComps = Set([Constants.abpkitDir])
        #else
        throw ABPFilterListError.notFound
        #endif
        return Set(url.pathComponents)
            .intersection(bundleComps) == bundleComps
    }

    /// Intended to prevent duplication of lists.
    private
    func replaceFilterListModel(_ list: FilterList,
                                lists: [FilterList]) throws -> [FilterList] {
        return try replaceModel(list,
                                models: lists)
    }

    private
    func replaceModel<T: Persistable>(_ model: T,
                                      models: [T]) throws -> [T] {
        var replaced = 0
        return try models
            .filter {
                if $0.name == model.name {
                    replaced += 1
                    return false
                }
                return true
            }
            .reduce([model]) {
                if replaced > 1 { throw ABPMutableStateError.ambiguousModels }
                return $0 + [$1]
            }
    }
}
