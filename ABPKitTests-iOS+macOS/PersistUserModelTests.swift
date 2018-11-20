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

@testable import ABPKit

import RxSwift
import XCTest

class PersistUserModelTests: XCTestCase {
    var bag: DisposeBag!
    let rndutil = RandomStateUtility()
    let rnd = { min, max in Int.random(in: min...max) }
    let min = 3
    let max = 10
    let testRuleCnt = 7
    let timeout: TimeInterval = 5
    var src: BlockListSourceable?
    var aae: Bool?
    var hosts: [WhitelistedHostname]!
    var names: [String]!

    override
    func setUp() {
        super.setUp()
        bag = DisposeBag()
        aae = rndutil.randomState(for: Bool.self)
        hosts = rndutil.randomState(for: [WhitelistedHostname].self)
        names = [String]()
    }

    override
    func tearDown() {
        do {
            var user = try User(fromPersistentStorage: true)
            user?.downloads = []
            try user?.save()
        } catch let err {
            if err as? ABPMutableStateError != .invalidType { XCTFail("Error: \(err)") }
        }
        super.tearDown()
    }

    func testUserSave() throws {
        let seed = try User()
        let user = try addDLs()(configUser()(seed))
        try user.save()
        let saved = try User(fromPersistentStorage: true)
        XCTAssert(saved?.acceptableAdsInUse() == aae,
                  "Bad AA state.")
        XCTAssert(saved?.whitelistedDomains == hosts,
                  "Bad WL state.")
        XCTAssert(saved?.blockList?.source as? BundledBlockList == self.src as? BundledBlockList,
                  "Bad BL source.")
        var cnt = 0
        for _ in 0...names.count - 1 {
            if try user.blockListNamed(names[rnd(0, names.count - 1)])(user.downloads ?? []) != nil {
                cnt += 1
            }
        }
        XCTAssert(cnt == names.count)
    }

    /// Use bundled testing source.
    func testRulesFromUser() throws {
        let expect = expectation(description: #function)
        let blst = try BlockList(withAcceptableAds: true, source: BundledTestingBlockList.fakeExceptions)
        var user = try User()
        user.blockList = blst
        let hlpr = RulesHelper()
        hlpr.useBundle = Bundle(for: PersistUserModelTests.self)
        try hlpr.validatedRules()(hlpr.rulesForUser()(user))
            .reduce(0) { acc, _ in return acc + 1 }
            .subscribe(onNext: { cnt in
                XCTAssert(cnt == self.testRuleCnt, "Rule count is wrong.")
            }, onCompleted: {
                expect.fulfill()
            }).disposed(by: bag)
        wait(for: [expect], timeout: timeout)
    }

    private
    func configUser() throws -> (User) throws -> User {
        return { user in
            var copy = user
            if self.aae != nil {
                self.hosts = self.rndutil.randomState(for: [WhitelistedHostname].self)
                switch self.aae! {
                case true:
                    copy.blockList = try BlockList(withAcceptableAds: true,
                                                   source: BundledBlockList.easylistPlusExceptions)
                    self.src = copy.blockList?.source
                case false:
                    copy.blockList = try BlockList(withAcceptableAds: false,
                                                   source: BundledBlockList.easylist)
                    self.src = copy.blockList?.source
                }
                copy.whitelistedDomains = self.hosts
            } else { XCTFail("Bad AA state.") }
            return copy
        }
    }

    private
    func addDLs() throws -> (User) throws -> (User) {
        return { user in
            var copy = user
            var dls = [BlockList]()
            let srcUtil = BlockListSourceUtility()
            for _ in 1...self.rnd(self.min, self.max) {
                if let boolRnd = self.rndutil.randomState(for: Bool.self),
                    let src = try srcUtil.srcForAAState(boolRnd)(self.rnd(0, 1)) {
                    var newBL = try BlockList(withAcceptableAds: boolRnd,
                                              source: src)
                    newBL.dateDownload = Date()
                    newBL.filename = UUID().uuidString
                    self.names.append(newBL.name)
                    copy.downloads?.append(newBL)
                    dls.append(newBL)
                } else { XCTFail("Bad random states.") }
            }
            return copy
        }
    }
}
