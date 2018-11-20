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

class RulesHelper {
    var bag: DisposeBag!
    /// Overrride default bundle, if set.
    var useBundle: Bundle?

    init() {
        bag = DisposeBag()
    }

    /// Get rules in the context of a user.
    public
    func rulesForUser() -> (User) throws -> URL? {
        return { user in
            guard let blst = user.blockList,
                  let name = user.name else { return nil }
            return try self.rulesURL(identifier: name,
                                     source: blst.source,
                                     withAA: user.acceptableAdsInUse())
        }
    }

    public
    func rulesForFilename() -> (String?) throws -> URL? {
        return {
            guard let name = $0 else { return nil }
            let containerURL = try Config().containerURL()
            let fileURL = containerURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fileURL.path) { return fileURL }
            return nil
        }
    }

    /// Return URL for local content blocking rules, the JSON file. The bundle may
    /// need to be explicitly set when accessing rules from a bundle other than the
    /// Config's bundle.
    /// Example: rulesURL(bundle: Bundle(for: ...))
    /// This function also handles BlockListSourceables during the transition to a
    /// final definition of FilterList.
    func rulesURL(identifier: String,
                  source: BlockListSourceable? = nil,
                  withAA: Bool = true,
                  bundle: Bundle = Config().bundle(),
                  ignoreBundle: Bool = false) throws -> URL? {
        let bndlToUse = useBundle ?? bundle
        if let url = fromBundledSourceable(source, withAA: withAA, bundle: bndlToUse) { return url }
        let matched = try Persistor()
            .loadFilterListModels()
            .filter { $0.name == identifier }
        switch matched.count {
        case let cnt where cnt == 0 :
            throw ABPFilterListError.notFound
        case let cnt where cnt != 0 && cnt != 1:
            throw ABPFilterListError.ambiguousModels
        default:
            break
        }
        let fname = matched.first?.fileName
        let url = try? Config().containerURL()
        let pathURL = fname != nil ? url?.appendingPathComponent(fname!) : nil
        if pathURL != nil && FileManager.default.fileExists(atPath: pathURL!.path) {
            return pathURL
        }
        // Only if URL not found in the container and not a BlockListSourceable, look in the bundle:
        if !ignoreBundle {
           return fromBundle(name: identifier, bundle: bndlToUse)
        }
        return nil
    }

    func fromBundledSourceable(_ source: BlockListSourceable?,
                               withAA: Bool,
                               bundle: Bundle) -> URL? {
        switch source {
        case let src where src as? BundledBlockList != nil:
            switch withAA {
            case true:
                return fromBundle(filename: BundledBlockList.easylistPlusExceptions.rawValue,
                                  bundle: bundle)
            case false:
                return fromBundle(filename: BundledBlockList.easylist.rawValue,
                                  bundle: bundle)
            }
        case let src where src as? BundledTestingBlockList != nil:
            switch withAA {
            case true:
                return fromBundle(filename: BundledTestingBlockList.fakeExceptions.rawValue,
                                  bundle: bundle)
            case false:
                return fromBundle(filename: BundledTestingBlockList.testingEasylist.rawValue,
                                  bundle: bundle)
            }
        default:
            return nil
        }
    }

    func validatedRules() -> (URL?) -> Observable<BlockingRule> {
        return {
            if $0 == nil { return Observable.error(ABPFilterListError.badSource) }
            guard let data = try? self.filterListData(url: $0!) else {
                return Observable.error(ABPFilterListError.badData)
            }
            guard let list =
                try? JSONDecoder().decode(V1FilterList.self,
                                          from: data)
            else {
                return Observable.error(ABPFilterListError.badData)
            }
            return list.rules()
        }
    }

    /// Match by filename.
    private
    func fromBundle(filename: String, bundle: Bundle) -> URL? {
        return try? ContentBlockerUtility()
            .getBundledFilterListFileURL(filename: filename,
                                         bundle: bundle)
    }

    /// Match a FilterList model by name.
    private
    func fromBundle(name: String, bundle: Bundle) -> URL? {
        return try? ContentBlockerUtility()
            .getBundledFilterListFileURL(modelName: name,
                                         bundle: bundle)
    }

    /// Get filter list data.
    /// - parameter url: File URL of the data
    /// - returns: Data of the filter list
    /// - throws: ABPKitTestingError
    private
    func filterListData(url: URL) throws -> Data {
        guard let data = try? Data(contentsOf: url,
                                   options: .uncached)
        else {
            throw ABPFilterListError.badData
        }
        return data
    }
}
