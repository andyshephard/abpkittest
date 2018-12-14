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

import RxCocoa

/// This class is for encapsulating legacy mutable states and configuration
/// values.
///
/// It also serves the following purposes
/// * An intermediary between the host app and app extension.
/// * Translate between Objective-C and Swift types during the migration of the
/// legacy app to ABPKit.
///   - The related selectors are prefixed with `legacy` for this purpose.
///
/// Usage:
///
///     let relay = AppExtensionRelay.sharedInstance()
///
/// This implementation only exists to serve the legacy ABP iOS app and will be
/// re-factored in a future version.
@objc
class AppExtensionRelay: NSObject {
    private static var privateSharedInstance: AppExtensionRelay?

    // ------------------------------------------------------------
    // MARK: - Legacy host app states -
    // ------------------------------------------------------------

    var acceptableAdsEnabled = BehaviorRelay<Bool?>(value: nil)
    var customFilterListEnabled = BehaviorRelay<Bool?>(value: nil)
    var defaultFilterListEnabled = BehaviorRelay<Bool?>(value: nil)
    var downloadedVersion = BehaviorRelay<Int?>(value: nil)
    var enabled = BehaviorRelay<Bool?>(value: nil)
    var filterLists = BehaviorRelay<[FilterList]>(value: [])
    var group = BehaviorRelay<String?>(value: nil)
    var installedVersion = BehaviorRelay<Int?>(value: nil)
    var lastActivity = BehaviorRelay<Date?>(value: nil)
    var shouldRespondToActivityTest = BehaviorRelay<Bool?>(value: nil)
    var whitelistedWebsites = BehaviorRelay<[String]>(value: [])

    // End legacy host app states

    override private
    init() {
        let cfg = Config()
        guard let grp = try? cfg.appGroup() else { return }
        self.group.accept(grp)
    }

    /// Destroy the shared instance in memory.
    class func destroy() {
        privateSharedInstance = nil
    }

    /// Access the shared instance.
    @objc
    class func sharedInstance() -> AppExtensionRelay {
        guard let shared = privateSharedInstance else {
            privateSharedInstance = AppExtensionRelay()
            return privateSharedInstance!
        }
        return shared
    }

    // ------------------------------------------------------------
    // MARK: - Legacy getters -
    // ------------------------------------------------------------

    @objc
    func legacyContentBlockerIdentifier() -> ContentBlockerIdentifier? {
        return Config().contentBlockerIdentifier(platform: .ios)
    }

    @objc
    func legacyGroup() -> AppGroupName? {
        return group.value
    }

    // ------------------------------------------------------------
    // MARK: - Legacy setters -
    // ------------------------------------------------------------

    @objc
    func legacyAcceptableAdsEnabledSet(_ acceptableAdsEnabled: Bool) {
        self.acceptableAdsEnabled.accept(acceptableAdsEnabled)
    }

    @objc
    func legacyCustomFilterListEnabledSet(_ customFilterListEnabled: Bool) {
        self.customFilterListEnabled.accept(customFilterListEnabled)
    }

    @objc
    func legacyDefaultFilterListEnabledSet(_ defaultFilterListEnabled: Bool) {
        self.defaultFilterListEnabled.accept(defaultFilterListEnabled)
    }

    @objc
    func legacyDownloadedVersionSet(_ downloadedVersion: Int) {
        self.downloadedVersion.accept(downloadedVersion)
    }

    @objc
    func legacyEnabledSet(_ enabled: Bool) {
        self.enabled.accept(enabled)
    }

    /// Add all Swift filter list structs from the legacy type.
    @objc
    func legacyFilterListsSet(_ filterLists: LegacyFilterLists) {
        var swiftLists = [FilterList]()
        for key in filterLists.keys {
            if let list = FilterList(named: key, fromDictionary: filterLists[key]) {
                swiftLists.append(list)
            }
        }
        self.filterLists.accept(swiftLists)
    }

    @objc
    func legacyInstalledVersionSet(_ installedVersion: Int) {
        self.installedVersion.accept(installedVersion)
    }

    @objc
    func legacyLastActivitySet(_ lastActivity: Date) {
        self.lastActivity.accept(lastActivity)
    }

    @objc
    func legacyWhitelistedWebsitesSet(_ whitelistedWebsites: [String]) {
        self.whitelistedWebsites.accept(whitelistedWebsites)
    }
}
