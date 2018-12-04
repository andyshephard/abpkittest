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

/// Helpers for encoding/decoding block list sources.
class SourceHelper {
    // swiftlint:disable cyclomatic_complexity
    func sourceDecoded() -> (String) throws -> BlockListSourceable {
        return { source in
            switch source.components(separatedBy: Constants.srcSep) {
            case let cmp1 where cmp1.first == Constants.srcBundled:
                switch cmp1 {
                case let cmp2 where cmp2.last == Constants.srcEasylist:
                    return BundledBlockList.easylist
                case let cmp2 where cmp2.last == Constants.srcEasylistPlusExceptions:
                    return BundledBlockList.easylistPlusExceptions
                default:
                    throw ABPFilterListError.failedDecoding
                }
            case let cmp1 where cmp1.first == Constants.srcRemote:
                switch cmp1 {
                case let cmp2 where cmp2.last == Constants.srcEasylist:
                    return RemoteBlockList.easylist
                case let cmp2 where cmp2.last == Constants.srcEasylistPlusExceptions:
                    return RemoteBlockList.easylistPlusExceptions
                default:
                    throw ABPFilterListError.failedDecoding
                }
            case let cmp1 where cmp1.first == Constants.srcTestingBundled:
                switch cmp1 {
                case let cmp2 where cmp2.last == Constants.srcTestingEasylist:
                    return BundledTestingBlockList.testingEasylist
                case let cmp2 where cmp2.last == Constants.srcTestingEasylistPlusExceptions:
                    return BundledTestingBlockList.fakeExceptions
                default:
                    throw ABPFilterListError.failedDecoding
                }
            case let cmp1 where cmp1.first == Constants.srcUserWhiteListLocallyGenerated:
                switch cmp1 {
                case let cmp2 where cmp2.last == Constants.srcAcceptableAdsNotApplicable:
                    return UserWhiteList.locallyGenerated
                default:
                    throw ABPFilterListError.failedDecoding
                }
            default:
                throw ABPFilterListError.failedDecoding
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable force_cast
    func sourceEncoded() -> (BlockListSourceable) throws -> String {
        return { source in
            switch source {
            case let type where type is BundledBlockList:
                switch source as! BundledBlockList {
                case .easylist:
                    return self.src2str(true, false, false)
                case .easylistPlusExceptions:
                    return self.src2str(true, true, false)
                }
            case let type where type is RemoteBlockList:
                switch source as! RemoteBlockList {
                case .easylist:
                    return self.src2str(false, false, false)
                case .easylistPlusExceptions:
                    return self.src2str(false, true, false)
                }
            case let type where type is BundledTestingBlockList:
                switch source as! BundledTestingBlockList {
                case .testingEasylist:
                    return self.src2str(true, false, true)
                case .fakeExceptions:
                    return self.src2str(true, true, true)
                }
            case let type where type is UserWhiteList:
                switch source as! UserWhiteList {
                case .locallyGenerated:
                    return self.src2str(false, false, false, true)
                }
            default:
                throw ABPFilterListError.badSource
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable force_cast

    private
    func src2str(_ isBundled: Bool,
                 _ isAA: Bool,
                 _ isTesting: Bool = false,
                 _ isUserWL: Bool = false) -> String {
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
        if isUserWL {
            type = Constants.srcUserWhiteListLocallyGenerated
            aae = Constants.srcAcceptableAdsNotApplicable
        }
        return sep(type)(aae)
    }
}
