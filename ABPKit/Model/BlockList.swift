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
/// Saved rules are named after the BlockList's name.
public
struct BlockList: BlockListable {
    /// Identifier.
    public let name: String
    /// Only settable at creation.
    public let source: BlockListSourceable
    var dateDownload: Date?

    enum CodingKeys: CodingKey {
        case name
        case source
        case dateDownload
    }

    public
    init(withAcceptableAds: Bool,
         source: BlockListSourceable,
         name: String? = nil,
         dateDownload: Date? = nil) throws {
        if try AcceptableAdsHelper().aaExists()(source) != withAcceptableAds {
            throw ABPFilterListError.aaStateMismatch
        }
        self.name = name ?? UUID().uuidString
        self.source = source
        self.dateDownload = dateDownload
    }

    public
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension BlockList {
    public
    func isExpired() -> Bool {
        if dateDownload != nil {
            return dateDownload!
                .addingTimeInterval(Constants.defaultFilterListExpiration)
                .timeIntervalSinceReferenceDate
            < Date.timeIntervalSinceReferenceDate
        }
        return true
    }
}

extension BlockList {
    public
    init(from decoder: Decoder) throws {
        let vals = try decoder.container(keyedBy: CodingKeys.self)
        name = try vals.decode(String.self, forKey: .name)
        dateDownload = try vals.decode(Date?.self, forKey: .dateDownload)
        source = try SourceHelper()
            .sourceDecoded()(vals.decode(String.self, forKey: .source))
    }

    public
    func encode(to encoder: Encoder) throws {
        var cntr = encoder.container(keyedBy: CodingKeys.self)
        try cntr.encode(name, forKey: .name)
        try cntr.encode(dateDownload, forKey: .dateDownload)
        try cntr.encode(SourceHelper().sourceEncoded()(source), forKey: .source)
    }
}

extension BlockList {
    public static
    func == (lhs: BlockList, rhs: BlockList) -> Bool {
        return lhs.name == rhs.name
    }
}
