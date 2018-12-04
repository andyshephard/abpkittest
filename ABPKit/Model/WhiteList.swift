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

 /// Internally generated block list.
struct WhiteList: BlockListable,
                  UserWhiteListable {
    let name: String
    let source: BlockListSourceable
    var dateModified: Date?
    public var hashValue: Int { return name.hashValue }

    enum CodingKeys: CodingKey {
        case name
        case source
        case dateModified
    }

    init() {
        name = UUID().uuidString
        source = UserWhiteList.locallyGenerated
        dateModified = nil
    }
}

extension WhiteList {
    public
    init(from decoder: Decoder) throws {
        let vals = try decoder.container(keyedBy: CodingKeys.self)
        name = try vals.decode(String.self, forKey: .name)
        dateModified = try vals.decode(Date?.self, forKey: .dateModified)
        source = try SourceHelper()
            .sourceDecoded()(vals.decode(String.self, forKey: .source))
    }

    public
    func encode(to encoder: Encoder) throws {
        var cntr = encoder.container(keyedBy: CodingKeys.self)
        try cntr.encode(name, forKey: .name)
        try cntr.encode(dateModified, forKey: .dateModified)
        try cntr.encode(SourceHelper().sourceEncoded()(source), forKey: .source)
    }
}

extension WhiteList {
    public static
    func == (lhs: WhiteList, rhs: WhiteList) -> Bool {
        return lhs.name == rhs.name
    }
}
