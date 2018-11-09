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
    let blockList = BundledBlockList.easylist
    let initialURLString = "https://adblockplus.org"
    var abp: ABPWebViewBlocker!
    var model: FilterList!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var unitTestingLabel: UILabel!
    @IBOutlet weak var urlField: UITextField!
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

    @IBAction func reloadWasPressed(_ sender: Any) {
        if let text = urlField.text {
            loadURLString(text)
        }
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
            self.urlField.text = urlString
        }
    }

    func reportTesting() {
        unitTestingLabel.isHidden = false
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
