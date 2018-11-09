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
    let blockList = BundledBlockList.easylist
    let initialURLString = "https://adblockplus.org"
    var abp: ABPWebViewBlocker!
    var model: FilterList!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var unitTestingField: NSTextField!
    @IBOutlet weak var urlField: NSTextField!
    @IBOutlet weak var webView: WKWebView!

    override
    func viewDidLoad() {
        super.viewDidLoad()
        disableControls()
        if ABPKit.isTesting() { reportTesting(); return }
        abp = ABPWebViewBlocker(host: self)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        urlField.delegate = self
        model = abp.makeTestModel(blockList: blockList)
        // Add and enable content blocking rules while loading a URL:
        abp.addRules { errors in
            guard errors == nil else {
                log("🚨 Errors: \(errors!)")
                return
            }
            self.loadURLString(self.initialURLString)
            self.enableControls()
        }
    }

    @IBAction func enterURLSelected(_ sender: Any) {
        self.view.window?.makeFirstResponder(urlField)
    }

    @IBAction func reloadWasPressed(_ sender: Any) {
        loadURLString(urlField.stringValue)
    }

    func loadURLString(_ urlString: String) {
        abp.loadURLString(urlString) { url, err in
            guard let uwURL = url,
                  err == nil
            else {
                log("🚨 Error: \(err!)")
                return
            }
            self.updateURLField(urlString: uwURL.absoluteString)
        }
    }

    func updateURLField(urlString: String) {
        DispatchQueue.main.async {
            self.urlField.stringValue = urlString
        }
    }

    func reportTesting() {
        unitTestingField.isHidden = false
        urlField.isEnabled = false
        reloadButton.isEnabled = false
        webView.isHidden = true
    }

    func disableControls() {
        urlField.isEnabled = false
        reloadButton.isEnabled = false
    }

    func enableControls() {
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
