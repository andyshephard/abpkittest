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

class RulesValidator {
    var bag: DisposeBag!

    init() {
        bag = DisposeBag()
    }

    func validatedRules(for url: BlockListFileURL) -> Observable<BlockingRule> {
        let decoder = JSONDecoder()
        guard let data = try? self.filterListData(url: url) else {
            return Observable.error(ABPFilterListError.badData)
        }
        guard let list =
            try? decoder.decode(V1FilterList.self,
                                from: data)
        else {
            return Observable.error(ABPFilterListError.badData)
        }
        return list.rules()
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
