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

/// Global functions for development only.

/// Log messages useful for debugging.
public
func log(_ message: String,
         filename: String = #file,
         line: Int = #line,
         function: String = #function) {
    #if DEBUG
        let newMsg = "-[\((filename as NSString).lastPathComponent):\(line)] \(function) - \(message)"
        NSLog(newMsg)
    #endif
}

/// Print out all of the user's filter lists.
public
func debugPrintFilterLists(_ lists: [FilterList],
                           caller: String? = nil) {
    #if DEBUG
        if caller != nil {
            NSLog("Called from \(caller!)")
        }
        NSLog("📜 Filter Lists:")
        var cnt = 1
        for list in lists {
            NSLog("\(cnt). \(list)\n")
            cnt += 1
        }
    #endif
}

/// Return true when tests are running.
public
func isTesting() -> Bool {
    return ProcessInfo().environment["XCTestConfigurationFilePath"] != nil
}
