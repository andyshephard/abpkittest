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

/// This is an extension that is called during CB operations as indicated by the
/// principal class in the extensions plist. It also depends on the bundle ID eg
/// org.adblockplus.HostApp-macOS.HostCBExt-macOS.
class ContentBlockerRequestHandler: NSObject,
                                    NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let rsrc = "easylist-42perc"
        guard let attachment =
            NSItemProvider(contentsOf: Bundle.main.url(forResource: rsrc,
                                                       withExtension: Constants.rulesExtension))
        else {
            return
        }
        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item],
                                completionHandler: { err in
            ABPKit.log("Error during beginRequest: \(err)")
        })
    }
}
