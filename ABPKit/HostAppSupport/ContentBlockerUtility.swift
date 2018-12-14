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
import RxSwift

/// Utility functions related to content blocking.
/// These support the ABP Safari iOS app.
class ContentBlockerUtility {
    var bag: DisposeBag!

    init() throws {
        bag = DisposeBag()
    }

    /// Get NS item provider for a resource matching filter list rules.
    /// - parameter resource: Name of JSON filter list without extension
    /// - returns: NSItemProvider for the attachment
    func getAttachment(resource: String) -> NSItemProvider? {
        return NSItemProvider(
            contentsOf: Bundle(for: ContentBlockerUtility.self)
                .url(forResource: resource, withExtension: Constants.rulesExtension))
    }

    /// Get filter list name based on the following legacy states:
    /// * acceptableAdsEnabled
    /// * defaultFilterListEnabled
    /// * State of custom filter list downloaded
    ///
    /// - returns: Name of filter list
    func activeFilterListName() -> FilterListName? {
        let cstm = Constants.customFilterListName
        let dfltAA = Constants.defaultFilterListPlusExceptionRulesName
        let dflt = Constants.defaultFilterListName
        let relay = AppExtensionRelay.sharedInstance()
        if relay.acceptableAdsEnabled.value == true {
            return dfltAA
        } else if relay.defaultFilterListEnabled.value == true {
            return dflt
        } else {
            if let customList =
                try? FilterList(persistenceID: cstm) {
                if relay.defaultFilterListEnabled.value == true && customList?.downloaded == true {
                    return cstm
                }
            }
        }
        return nil
    }

    /// Get the internal name of a Filter List model object.
    func filterListFilename(name: FilterListName) -> String {
        switch name {
        case Constants.defaultFilterListName:
            return Constants.defaultFilterListFilename
        case Constants.defaultFilterListPlusExceptionRulesName:
            return Constants.defaultFilterListPlusExceptionRulesFilename
        default:
            return ""
        }
    }

    /// Legacy function: Get the filter list rules file URL from the bundle.
    /// - returns: File URL for the filter list rules
    /// - throws: ABPFilterListError
    func activeFilterListsURL() throws -> FilterListFileURL {
        if AppExtensionRelay.sharedInstance().enabled.value == true {
            guard let name = activeFilterListName() else { throw ABPFilterListError.missingName }
            return try getBundledFilterListFileURL(modelName: name)
        }
        throw ABPFilterListError.notFound
    }

    /// Retrieve a reference (file URL) to a blocklist file in a bundle.
    /// - parameter name: The given name for a filter list.
    /// - parameter bundle: Defaults to config bundle.
    func getBundledFilterListFileURL(modelName: FilterListName,
                                     bundle: Bundle = Config().bundle()) throws -> FilterListFileURL {
        if let model = try? FilterList(persistenceID: modelName),
           let filename = model?.fileName {
            if let url = bundle.url(forResource: filename, withExtension: "") {
                return url
            } else { throw ABPFilterListError.notFound }
        }
        throw ABPFilterListError.notFound
    }

    /// Get bundled rules by filename only.
    func getBundledFilterListFileURL(filename: String,
                                     bundle: Bundle = Config().bundle()) throws -> FilterListFileURL {
        if let url = bundle.url(forResource: filename, withExtension: "") {
            return url
        } else { throw ABPFilterListError.notFound }
    }

    func filenameFromURL(_ url: BlockListFileURL) -> BlockListFilename {
        return url.lastPathComponent
    }

    /// Legacy FilterList implementation.
    func mergedFilterListRules(from sourceURL: BlockListFileURL,
                               with whitelistedWebsites: WhitelistedWebsites,
                               limitRuleMaxCount: Bool = false) -> Observable<BlockListFileURL> {
        let maxRuleCount = 1 // for unit testing only
        let filename = "ww-\(filenameFromURL(sourceURL))"
        let encoder = JSONEncoder()
        let dir = self.rulesDir(blocklist: sourceURL)
        let dest = self.makeNewBlocklistFileURL(name: filename, at: dir)
        var ruleList: V1FilterList!
        do {
            ruleList = try JSONDecoder()
                .decode(V1FilterList.self, from: self.blocklistData(blocklist: sourceURL))
             try self.startBlockListFile(blocklist: dest)
        } catch let err { return Observable.error(err) }
        var cnt = 0
        return ruleList.rules()
            .takeWhile { _ in
                if limitRuleMaxCount { return cnt < maxRuleCount }
                return true
            }
            .flatMap { (rule: BlockingRule) -> Observable<BlockListFileURL> in
                cnt += 1
                guard let coded = try? encoder.encode(rule) else {
                    return Observable.error(ABPFilterListError.failedEncodeRule)
                }
                self.writeToEndOfFile(blocklist: dest, with: coded)
                self.addRuleSeparator(blocklist: dest)
                return Observable.create { observer in
                    whitelistedWebsites.forEach {
                        do {
                            let data = try encoder.encode(self.whiteListRuleForDomains()([$0]))
                            self.writeToEndOfFile(blocklist: dest, with: data)
                            self.addRuleSeparator(blocklist: dest)
                        } catch let err { observer.onError(err); return }
                    }
                    self.endBlockListFile(blocklist: dest)
                    observer.onNext(dest)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
    }
}
