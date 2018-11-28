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
import Cocoa
import WebKit

// ABP content blocking example for macOS.
@available(macOS 10.13, *)
class WebViewVC: NSViewController,
                 ABPBlockable,
                 NSTextFieldDelegate,
                 WKNavigationDelegate,
                 WKUIDelegate {
    @IBOutlet weak var aaCheckButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var unitTestingField: NSTextField!
    @IBOutlet weak var urlField: NSTextField!
    @IBOutlet weak var webView: WKWebView!
    let initialURLString = "https://adblockplus.org"
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
            abp = try ABPWebViewBlocker(host: self)
            try self.clearUserState()
            try setupABP {
                self.enableControls()
            }
        } catch let err { log("🚨 Error: \(err)") }
    }

    func setupABP(aaChangeTo: Bool? = nil, completion: @escaping () -> Void) throws {
        DispatchQueue.main.async { log("👩🏻‍🎤0 \(self.userHist(self.abp))") }
        if aaChangeTo != nil { try changeUserAA(aaChangeTo!) }
        updateAA(abp.user.acceptableAdsInUse())
        // Add and enable content blocking rules while loading a URL:
        try abp.addExistingRuleList { added in
            if added {
                self.loadURLString(self.location ?? self.initialURLString)
                DispatchQueue.main.async { log("👩🏻‍🎤1 \(self.userHist(self.abp))") }
                completion()
            } else {
                self.abp.addRules { errors in
                    guard errors == nil else {
                        log("🚨 Errors: \(errors!)")
                        do {
                            try self.clearUserState()
                        } catch let err { log("Error: \(err)") }
                        log("😎 Try running again. Cleared user state.")
                        return
                    }
                    DispatchQueue.main.async { log("👩🏻‍🎤2 \(self.userHist(self.abp))") }
                    self.loadURLString(self.location ?? self.initialURLString)
                    completion()
                }
            }
        }
    }

    func changeUserAA(_ aaIsOn: Bool) throws {
        var src: BlockListSourceable!
        switch aaIsOn {
        case true:
            src = BundledBlockList.easylistPlusExceptions
        case false:
            src = BundledBlockList.easylist
        }
        let blockList = try BlockList(withAcceptableAds: aaIsOn,
                                      source: src)
        abp.user.setBlockList(blockList)
        try abp.user.save()
    }

    /// Can be used to recover from errors.
    func clearUserState() throws {
        let user = try User()
        self.abp.user = user
        try user.save()
    }

    // ------------------------------------------------------------
    // MARK: - Actions -
    // ------------------------------------------------------------

    @IBAction func enterURLSelected(_ sender: Any) {
        self.view.window?.makeFirstResponder(urlField)
    }

    @IBAction func aaPressed(_ sender: Any) {
        disableControls()
        do {
            try setupABP(aaChangeTo: aaCheckButton.state == .off ? false : true) {
                self.enableControls()
            }
        } catch let err { log("🚨 Error: \(err)") }
    }

    @IBAction func reloadPressed(_ sender: Any) {
        loadURLString(urlField.stringValue)
    }

    // ------------------------------------------------------------

    func loadURLString(_ urlString: String) {
        abp.loadURLString(urlString) { url, err in
            guard let uwURL = url,
                  err == nil else { log("🚨 Error: \(err!)"); return }
            self.updateURLField(urlString: uwURL.absoluteString)
            self.location = uwURL.absoluteString
        }
    }

    func updateURLField(urlString: String) {
        DispatchQueue.main.async {
            self.urlField.stringValue = urlString
        }
    }

    func reportTesting() {
        unitTestingField.isHidden = false
        aaCheckButton.isEnabled = false
        urlField.isEnabled = false
        reloadButton.isEnabled = false
        webView.isHidden = true
    }

    func updateAA(_ withAA: Bool) {
        switch withAA {
        case true:
            aaCheckButton.state = .on
        case false:
            aaCheckButton.state = .off
        }
    }

    func disableControls() {
        aaCheckButton.isEnabled = false
        urlField.isEnabled = false
        reloadButton.isEnabled = false
    }

    func enableControls() {
        aaCheckButton.isEnabled = true
        urlField.isEnabled = true
        reloadButton.isEnabled = true
    }

    // ------------------------------------------------------------
    // MARK: - NSTextFieldDelegate -
    // ------------------------------------------------------------

    func controlTextDidEndEditing(_ obj: Notification) {
        loadURLString(urlField.stringValue)
    }
}
