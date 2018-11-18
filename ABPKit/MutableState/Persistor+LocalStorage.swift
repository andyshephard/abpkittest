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
    func clearRulesFiles(onlyLog: Bool = false) throws {
        let storeSuffix = "store"
        let mgr = FileManager.default
        let url = try Config().containerURL()
        guard let enmrtr =
            mgr.enumerator(at: url,
                           includingPropertiesForKeys: [.isDirectoryKey,
                                                        .nameKey],
                           options: [.skipsHiddenFiles,
                                     .skipsPackageDescendants],
                           errorHandler: { _, err -> Bool in
                ABPKit.log("Error during enumeration: \(err)")
                return true
            })
            else { return }
        var paths = [String]()
        while let fileURL = enmrtr.nextObject() as? URL {
            if fileURL
                .lastPathComponent
                .split(separator: ".")
                .contains(Substring(Constants.rulesExtension)) {
                    if !onlyLog {
                        do {
                            try mgr.removeItem(at: fileURL)
                            ABPKit.log("🗑️ \(fileURL.path)")
                        } catch let err { throw err }
                    } else {
                        paths.append(fileURL.path)
                    }
                }
                if fileURL
                    .lastPathComponent
                    .contains(Substring(storeSuffix)) {
                    paths.append(fileURL.path)
                }
        }
        paths.forEach {
            ABPKit.log("🔵 \($0)")
        }
    }
}
