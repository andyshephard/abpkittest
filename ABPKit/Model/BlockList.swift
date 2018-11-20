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

/// Represents content blocking lists for WKWebView and Safari.
/// FilterList represents the legacy data model that is linked to this newer model.
/// FilterList will likely be reconfigured/renamed in the future.
/// Currently, this struct is not separately Persistable, because it is stored in User.
public
struct BlockList: Codable {
    /// Identifier.
    public let name: String
    public let source: BlockListSourceable
    public var dateDownload: Date?
    public var filename: String?

    enum CodingKeys: CodingKey {
        case name
        case source
        case dateDownload
        case filename
    }

    public
    init(withAcceptableAds: Bool,
         source: BlockListSourceable) throws {
        guard withAcceptableAds == source.hasAcceptableAds() else {
            throw ABPFilterListError.aaStateMismatch
        }
        name = UUID().uuidString
        self.source = source
    }
}

extension BlockList {
    // swiftlint:disable cyclomatic_complexity
    public
    init(from decoder: Decoder) throws {
        let vals = try decoder.container(keyedBy: CodingKeys.self)
        name = try vals.decode(String.self, forKey: .name)
        dateDownload = try vals.decode(Date?.self, forKey: .dateDownload)
        filename = try vals.decode(String?.self, forKey: .filename)
        let src = try vals.decode(String.self, forKey: .source)
        switch src.components(separatedBy: Constants.srcSep) {
        case let cmp1 where cmp1.first == Constants.srcBundled:
            switch cmp1 {
            case let cmp2 where cmp2.last == Constants.srcEasylist:
                source = BundledBlockList.easylist
            case let cmp2 where cmp2.last == Constants.srcEasylistPlusExceptions:
                source = BundledBlockList.easylistPlusExceptions
            default:
                throw ABPFilterListError.failedDecoding
            }
        case let cmp1 where cmp1.first == Constants.srcRemote:
            switch cmp1 {
            case let cmp2 where cmp2.last == Constants.srcEasylist:
                source = RemoteBlockList.easylist
            case let cmp2 where cmp2.last == Constants.srcEasylistPlusExceptions:
                source = RemoteBlockList.easylistPlusExceptions
            default:
                throw ABPFilterListError.failedDecoding
            }
        case let cmp1 where cmp1.first == Constants.srcTestingBundled:
            switch cmp1 {
            case let cmp2 where cmp2.last == Constants.srcTestingEasylist:
                source = BundledTestingBlockList.testingEasylist
            case let cmp2 where cmp2.last == Constants.srcTestingEasylistPlusExceptions:
                source = BundledTestingBlockList.fakeExceptions
            default:
                throw ABPFilterListError.failedDecoding
        }
        default:
            throw ABPFilterListError.failedDecoding
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension BlockList {
    public
    func encode(to encoder: Encoder) throws {
        var cntr = encoder.container(keyedBy: CodingKeys.self)
        try cntr.encode(name, forKey: .name)
        try cntr.encode(dateDownload, forKey: .dateDownload)
        try cntr.encode(filename, forKey: .filename)
        let enc: (Bool, Bool, Bool) throws -> Void = {
            try cntr.encode(self.src2str($0, $1, $2), forKey: .source)
        }
        // swiftlint:disable force_cast
        switch source {
        case let type where type is BundledBlockList:
            switch source as! BundledBlockList {
            case .easylist:
                try enc(true, false, false)
            case .easylistPlusExceptions:
                try enc(true, true, false)
            }
        case let type where type is RemoteBlockList:
            switch source as! RemoteBlockList {
            case .easylist:
                try enc(false, false, false)
            case .easylistPlusExceptions:
                try enc(false, true, false)
            }
        case let type where type is BundledTestingBlockList:
            switch source as! BundledTestingBlockList {
            case .testingEasylist:
                try enc(true, false, true)
            case .fakeExceptions:
                try enc(true, true, true)
            }
        default:
            throw ABPFilterListError.badSource
        }
        // swiftlint:enable force_cast
    }

    private
    func src2str(_ isBundled: Bool, _ isAA: Bool, _ isTesting: Bool = false) -> String {
        let sep: (String) -> (String) -> String = { inp in
            return { [inp, $0].joined(separator: Constants.srcSep) }
        }
        var type: String!
        var aae: String!
        if isTesting {
            type = Constants.srcTestingBundled
            aae = !isAA ? Constants.srcTestingEasylist : Constants.srcTestingEasylistPlusExceptions
        } else {
            type = isBundled ? Constants.srcBundled : Constants.srcRemote
            aae = !isAA ? Constants.srcEasylist : Constants.srcEasylistPlusExceptions
        }
        return sep(type)(aae)
    }
}
