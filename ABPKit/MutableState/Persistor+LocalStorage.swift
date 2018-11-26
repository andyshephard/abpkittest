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

extension Persistor {
    /// Show files in the container.
    public
    func logRulesFiles() throws {
        try clearRulesFiles(onlyLog: true)
    }

    /// Wipe out rules files in the current configured container.
    public
    func clearRulesFiles() throws {
        try clearRulesFiles(onlyLog: false)
    }

    private
    func fileEnumerator(root: URL) -> FileManager.DirectoryEnumerator? {
        return
            FileManager.default
                .enumerator(at: root,
                            includingPropertiesForKeys: [.isDirectoryKey,
                                                         .nameKey],
                            options: [.skipsHiddenFiles,
                                      .skipsPackageDescendants],
                            errorHandler: { _, err -> Bool in
                    ABPKit.log("Error during enumeration: \(err)")
                    return true
                })
    }

    private
    func jsonFile() -> (URL) -> Bool {
        return {
            $0
                .lastPathComponent
                .split(separator: ".")
                .contains(Substring(Constants.rulesExtension))
            }
    }

    private
    func storeFile() -> (URL) -> Bool {
        let storeSuffix = "store"
        return {
            $0
                .lastPathComponent
                .contains(Substring(storeSuffix))
            }
    }

    private
    func clearRulesFiles(onlyLog: Bool = false) throws {
        let mgr = FileManager.default
        let url = try Config().containerURL()
        let enmrtr = fileEnumerator(root: url)
        var paths = [String]()
        while let fileURL = enmrtr?.nextObject() as? URL {
            if jsonFile()(fileURL) {
                if !onlyLog {
                    do {
                        try mgr.removeItem(at: fileURL)
                        ABPKit.log("🗑️ \(fileURL.path)")
                    } catch let err { throw err }
                } else {
                    paths.append(fileURL.path)
                }
            }
            if storeFile()(fileURL) {
                paths.append(fileURL.path)
            }
        }
        paths.sorted().forEach {
            ABPKit.log("🔵 \($0)")
        }
       ABPKit.log("")
    }
}
