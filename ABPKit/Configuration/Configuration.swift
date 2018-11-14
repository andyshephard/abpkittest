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

import Foundation

// Constants and functions intended for global scope.

/// Constants that are global to the framework.
public
struct Constants {
    /// Limit for background operations, less than the allowed limit to allow time for content blocker reloading.
    static let backgroundOperationLimit: TimeInterval = 28
    /// Default interval for expiration of a filter list.
    public static let defaultFilterListExpiration: TimeInterval = 86400
    /// Internal name.
    public static let customFilterListName = "customFilterList"
    /// Internal name.
    public static let defaultFilterListName = "easylist"
    /// Internal name.
    public static let defaultFilterListPlusExceptionRulesName = "easylist+exceptionrules"
    /// On-disk name.
    public static let defaultFilterListFilename = "easylist_content_blocker.json"
    /// On-disk name.
    // swiftlint:disable identifier_name
    public static let defaultFilterListPlusExceptionRulesFilename = "easylist+exceptionrules_content_blocker.json"
    // swiftlint:enable identifier_name
    /// On-disk name.
    public static let emptyFilterListFilename = "empty.json"
    /// On-disk name.
    public static let customFilterListFilename = "custom.json"

    public static let blocklistEncoding = String.Encoding.utf8
    public static let blocklistArrayStart = "["
    public static let blocklistArrayEnd = "]"
    public static let blocklistRuleSeparator = ","

    public static let contentRuleStoreID = "wk-content-rule-list-store"
    public static let rulesExtension = "json"

    public static let organization = "org.adblockplus"

    /// Internal distribution label for eyeo.
    public static let devbuildsName = "devbuilds"

    public static let groupMac = "group.org.adblockplus.abpkit-macos"
    public static let productNameIOS = "AdblockPlusSafari"
    public static let productNameMacOS = "HostApp-macOS"
    public static let extensionSafariNameIOS = "AdblockPlusSafariExtension"
    public static let extensionSafariNameMacOS = "HostCBExt-macOS"
    public static let abpkitDir = "ABPKit.framework"
    public static let abpkitResourcesDir = "Resources"
}

/// ABPKit configuration class for accessing globally relevant functions.
public
class Config {
    let adblockPlusSafariActionExtension = "AdblockPlusSafariActionExtension"
    let backgroundSession = "BackgroundSession"

    public
    init() {
        // Intentionally empty.
    }

    /// References the host app.
    /// Returns app identifier prefix such as:
    /// * org.adblockplus.devbuilds or
    /// * org.adblockplus
    private
    func bundlePrefix() -> BundlePrefix? {
        if let comps = Bundle.main.bundleIdentifier?.components(separatedBy: ".") {
            var newComps = [String]()
            if comps.contains(Constants.devbuildsName) {
                newComps = Array(comps[0...2])
            } else {
                newComps = Array(comps[0...1])
            }
            return newComps.joined(separator: ".")
        }
        return nil
    }

    /// Bundle reference for resources including:
    /// * bundled blocklists
    public
    func bundle() -> Bundle {
        return Bundle(for: Config.self)
    }

    public
    func appGroup() throws -> AppGroupName {
        if let name = bundlePrefix() {
            #if os(iOS)
            let grp = "group.\(name).\(Constants.productNameIOS)"
            #else
            let grp = Constants.groupMac
            #endif
            return grp
        }
        throw ABPConfigurationError.invalidAppGroup
    }

    /// This suite name comes from the legacy app.
    public
    func defaultsSuiteName() throws -> DefaultsSuiteName {
        guard let name = try? appGroup() else {
            throw ABPMutableStateError.missingDefaultsSuiteName
        }
        return name
    }

    /// A copy of the content blocker identifier function found in the legacy ABP implementation.
    /// - returns: A content blocker ID such as
    ///            "org.adblockplus.devbuilds.AdblockPlusSafari.AdblockPlusSafariExtension" or nil
    public
    func contentBlockerIdentifier(platform: ABPPlatform) -> ContentBlockerIdentifier? {
        guard let name = bundlePrefix() else { return nil }
        switch platform {
        case .ios:
            return "\(name).\(Constants.productNameIOS).\(Constants.extensionSafariNameIOS)"
        case .macos:
            return "\(name).\(Constants.productNameMacOS).\(Constants.extensionSafariNameMacOS)"
        }
    }

    public
    func backgroundSessionConfigurationIdentifier() throws -> String {
        guard let prefix = bundlePrefix() else {
            throw ABPConfigurationError.invalidBundlePrefix
        }
        return "\(prefix).\(Constants.productNameIOS).\(backgroundSession)"
    }

    public
    func containerURL() throws -> AppGroupContainerURL {
        let mgr = FileManager.default
        guard let grp = try? appGroup(),
              let url = mgr.containerURL(forSecurityApplicationGroupIdentifier: grp)
        else {
            throw ABPConfigurationError.invalidAppGroup
        }
        return url
    }

    public
    func rulesStoreIdentifier() throws -> URL {
        do {
            let cntr = try containerURL()
            let rsid = cntr.appendingPathComponent(Constants.contentRuleStoreID)
            return rsid
        } catch let err { throw err }
    }
}
