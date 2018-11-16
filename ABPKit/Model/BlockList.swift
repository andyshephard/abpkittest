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
/// There is overlap with FilterList from the legacy app.
/// Resolving these semantics is a future matter.
public
struct BlockList: Codable {
    public var source: BlockListSourceable?

    enum CodingKeys: CodingKey {
        case source
    }

    public
    init(withAcceptableAds: Bool,
         source: BlockListSourceable) throws {
        guard withAcceptableAds == source.hasAcceptableAds() else {
            throw ABPFilterListError.aaStateMismatch
        }
        self.source = source
    }
}

extension BlockList {
    public
    init(from decoder: Decoder) throws {
        let vals = try decoder.container(keyedBy: CodingKeys.self)
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
        default:
            throw ABPFilterListError.failedDecoding
        }
    }
}

extension BlockList {
    public
    func encode(to encoder: Encoder) throws {
        var cntr = encoder.container(keyedBy: CodingKeys.self)
        let enc: (Bool, Bool) throws -> Void = {
            try cntr.encode(self.src2str($0, $1), forKey: .source)
        }
        // swiftlint:disable force_cast
        switch source {
        case let type where type is BundledBlockList:
            switch source as! BundledBlockList {
            case .easylist:
                try enc(true, false)
            case .easylistPlusExceptions:
                try enc(true, true)
            }
        case let type where type is RemoteBlockList:
            switch source as! RemoteBlockList {
            case .easylist:
                try enc(false, false)
            case .easylistPlusExceptions:
                try enc(false, true)
            }
        default:
            throw ABPFilterListError.badSource
        }
        // swiftlint:enable force_cast
    }

    private
    func src2str(_ isBundled: Bool, _ isAA: Bool) -> String {
        let sep: (String) -> (String) -> String = { inp in
            return { [inp, $0].joined(separator: Constants.srcSep) }
        }
        let type = isBundled ? Constants.srcBundled : Constants.srcRemote
        let aae = !isAA ? Constants.srcEasylist : Constants.srcEasylistPlusExceptions
        return sep(type)(aae)
    }
}
