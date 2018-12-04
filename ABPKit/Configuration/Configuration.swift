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

/// Constants that are global to the framework. Not all are relevant in all
/// contexts as some are only applicable to the legacy iOS app.
public
struct Constants {
    public static let rulesExtension = "json"
    /// Default interval for expiration of a block list.
    static let defaultFilterListExpiration: TimeInterval = 86400
    /// Internal distribution label for eyeo.
    static let devbuildsName = "devbuilds"
    static let abpkitDir = "ABPKit.framework"
    static let abpkitResourcesDir = "Resources"
    static let blocklistArrayEnd = "]"
    static let blocklistArrayStart = "["
    static let blocklistEncoding = String.Encoding.utf8
    static let blocklistRuleSeparator = ","
    static let contentRuleStoreID = "wk-content-rule-list-store"
    static let extensionSafariNameIOS = "AdblockPlusSafariExtension"
    static let extensionSafariNameMacOS = "HostCBExt-macOS"
    static let groupMac = "group.org.adblockplus.abpkit-macos"
    static let organization = "org.adblockplus"
    static let productNameIOS = "AdblockPlusSafari"
    static let productNameMacOS = "HostApp-macOS"
    static let srcAcceptableAdsNotApplicable = "aa-na"
    static let srcBundled = "bundled"
    static let srcEasylist = "easylist"
    static let srcEasylistPlusExceptions = "easylistPlusExceptions"
    static let srcRemote = "remote"
    static let srcSep = "/"
    static let srcTestingBundled = "bundled-testing"
    static let srcTestingEasylist = "test-easylist"
    static let srcTestingEasylistPlusExceptions = "test-easylistPlusExceptions"
    static let srcUserWhiteListLocallyGenerated = "user-whitelist-locally-generated"
    static let userBlockListMax = 5
    static let userWhiteListMax = 2

    // MARK: - Legacy -

    /// Limit for background operations, less than the allowed limit to allow time for content blocker reloading.
    static let backgroundOperationLimit: TimeInterval = 28
    /// Internal name.
    public static let customFilterListName = "customFilterList"
    /// Internal name.
    public static let defaultFilterListName = "easylist"
    /// Internal name.
    public static let defaultFilterListPlusExceptionRulesName = "easylist+exceptionrules"
    /// On-disk name.
    public static let defaultFilterListFilename = "easylist_content_blocker.json"
    // swiftlint:disable identifier_name
    /// On-disk name.
    public static let defaultFilterListPlusExceptionRulesFilename = "easylist+exceptionrules_content_blocker.json"
    // swiftlint:enable identifier_name
    /// On-disk name.
    public static let emptyFilterListFilename = "empty.json"
    /// On-disk name.
    public static let customFilterListFilename = "custom.json"
}

/// ABPKit configuration class for accessing globally relevant functions.
public
class Config {
    let adblockPlusSafariActionExtension = "AdblockPlusSafariActionExtension"
    let backgroundSession = "BackgroundSession"

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
    func bundle() -> Bundle {
        return Bundle(for: Config.self)
    }

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
    func defaultsSuiteName() throws -> DefaultsSuiteName {
        return try appGroup()
    }

    /// A copy of the content blocker identifier function found in the legacy ABP implementation.
    /// - returns: A content blocker ID such as
    ///            "org.adblockplus.devbuilds.AdblockPlusSafari.AdblockPlusSafariExtension" or nil
    func contentBlockerIdentifier(platform: ABPPlatform) -> ContentBlockerIdentifier? {
        guard let name = bundlePrefix() else { return nil }
        switch platform {
        case .ios:
            return "\(name).\(Constants.productNameIOS).\(Constants.extensionSafariNameIOS)"
        case .macos:
            return "\(name).\(Constants.productNameMacOS).\(Constants.extensionSafariNameMacOS)"
        }
    }

    func backgroundSessionConfigurationIdentifier() throws -> String {
        guard let prefix = bundlePrefix() else {
            throw ABPConfigurationError.invalidBundlePrefix
        }
        return "\(prefix).\(Constants.productNameIOS).\(backgroundSession)"
    }

    func containerURL() throws -> AppGroupContainerURL {
        if let url = try FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup()) {
                return url
            }
        throw ABPConfigurationError.invalidContainerURL
    }

    func rulesStoreIdentifier() throws -> URL {
        do {
            return try containerURL().appendingPathComponent(Constants.contentRuleStoreID)
        } catch let err { throw err }
    }
}
