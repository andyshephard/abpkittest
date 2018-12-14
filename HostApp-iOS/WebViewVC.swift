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

import ABPKit
import UIKit
import WebKit

// ABP content blocking example for iOS.
@available(iOS 11.0, *)
class WebViewVC: UIViewController,
                 ABPBlockable,
                 UITextFieldDelegate,
                 WKNavigationDelegate,
                 WKUIDelegate {
    @IBOutlet weak var aaButton: UIButton!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var urlField: UITextField!
    @IBOutlet weak var webView: WKWebView!
    let aaOff = "AA is Off"
    let aaOn = "AA is On"
    let initialURLString = "https://adblockplus.org"
    /// When true, no remote blocklist downloads will be used.
    let noRemote = false
    let statusDuration: TimeInterval = 20
    let switchToDLMessage = "Switched to Downloaded Rules"
    /// Domain names hardcoded here will be whitelisted for the user.
    let whitelistedDomains: [String] = []
    var abp: ABPWebViewBlocker!
    var location: String?
    private let userHist: (ABPWebViewBlocker) -> [String] = {
        $0.user.getHistory()?.reduce([]) { $0 + [$1.name] } ?? ["missing"]
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        disableControls()
        if ABPKit.isTesting() { reportTesting(); return }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        urlField.delegate = self
        do {
            abp = try ABPWebViewBlocker(host: self, user: clearedStateUser(), noRemote: noRemote)
            try setupABP { self.enableControls() }
        } catch let err { log("🚨 Error: \(err)") }
    }

    /// Add and enable content blocking rules while loading a URL and start
    /// download of remote sources. Some user caching is logged.
    func setupABP(aaChangeTo: Bool? = nil, completion: @escaping () -> Void) throws {
        log("👩🏻‍🎤0 hist \(self.userHist(self.abp))")
        if aaChangeTo != nil { try changeUserAA(aaChangeTo!) }
        try updateAA(self.abp.lastUser().acceptableAdsInUse())
        abp.useContentBlocking(logBlockListSwitch: {
            self.reportStatus(self.switchToDLMessage)
            log("▶️ \(self.switchToDLMessage)")
        }, logUserState: { user in
            log("👩🏻‍🎤1 blst \(user.getBlockList() as BlockList?)")
            log("👩🏻‍🎤1 hist \(user.getHistory() as [BlockList]?)")
            log("👩🏻‍🎤1 dlds \(user.getDownloads() as [BlockList]?)")
            log("👩🏻‍🎤1 wldm \(user.getWhiteListedDomains() as [String]?)")
        }, completeWith: { err in
            if err != nil { log("🚨 Error: \(err as Error?)") }
            self.loadURLString(self.location ?? self.initialURLString)
            completion()
        })
    }

    func changeUserAA(_ aaIsOn: Bool) throws {
        if let dls = abp.user.getDownloads(), dls.count >= RemoteBlockList.allCases.count {
            if let remoteList = try
                UserStateHelper(user: self.abp.user)
                    .downloadsMatch()(SourceHelper()
                    .remoteSourceForAA()(aaIsOn)) {
                        abp.user = try abp.user.blockListSet()(remoteList).saved()
                    } else { throw ABPFilterListError.badSource }
            return
        }
        // Downloads not ready:
        abp.user = try abp.user.blockListSet()(BlockList(
            withAcceptableAds: aaIsOn,
            source: SourceHelper().bundledSourceForAA()(aaIsOn)))
            .saved()
    }

    func clearedStateUser() throws -> User {
        return try User().whiteListedDomainsSet()(whitelistedDomains).saved()
    }

    // ------------------------------------------------------------
    // MARK: - Actions -
    // ------------------------------------------------------------

    @IBAction func aaPressed(_ sender: Any) {
        disableControls()
        do {
            try setupABP(aaChangeTo: aaButton.title(for: .normal) == aaOn ? false : true) {
                self.enableControls()
            }
        } catch let err { log("🚨 Error: \(err)") }
    }

    @IBAction func reloadPressed(_ sender: Any) {
        if let text = urlField.text {
            loadURLString(text)
        }
    }

    // ------------------------------------------------------------

    func loadURLString(_ urlString: String) {
        abp.loadURLString(urlString) { url, err in
            guard let url = url, err == nil else { log("🚨 Error: \(err!)"); return }
            self.updateURLField(urlString: url.absoluteString)
            self.location = url.absoluteString
        }
    }

    func updateURLField(urlString: String) {
        DispatchQueue.main.async {
            self.urlField.text = urlString
        }
    }

    func reportTesting() {
        DispatchQueue.main.async {
            self.statusLabel.isHidden = false
            self.urlField.isEnabled = false
            self.reloadButton.isEnabled = false
            self.webView.isHidden = true
        }
    }

    func reportStatus(_ status: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = status
            self.statusLabel.isHidden = false
            UIView.animate(
                withDuration: self.statusDuration,
                delay: 0,
                options: .curveEaseIn,
                animations: { self.statusLabel.alpha = 0 },
                completion: { _ in
                    self.statusLabel.isHidden = true
                    self.statusLabel.alpha = 1
                })
        }
    }

    func updateAA(_ withAA: Bool) {
        DispatchQueue.main.async {
            switch withAA {
            case true:
                self.aaButton.setTitle(self.aaOn, for: .normal)
            case false:
                self.aaButton.setTitle(self.aaOff, for: .normal)
            }
        }
    }

    func disableControls() {
        DispatchQueue.main.async {
            self.aaButton.isEnabled = false
            self.urlField.isEnabled = false
            self.reloadButton.isEnabled = false
        }
    }

    func enableControls() {
        DispatchQueue.main.async {
            self.aaButton.isEnabled = true
            self.urlField.isEnabled = true
            self.reloadButton.isEnabled = true
        }
    }

    // ------------------------------------------------------------
    // MARK: - UITextFieldDelegate -
    // ------------------------------------------------------------

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = urlField.text {
            loadURLString(text)
            textField.resignFirstResponder()
            return true
        }
        return false
    }
}
