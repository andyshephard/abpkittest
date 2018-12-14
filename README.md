ABPKit
======
A content blocker management framework for iOS and macOS supporting both Safari and WKWebView.

## History
This project serves the future of content blocking on iOS and macOS after evolving out of the ABP for Safari iOS app. Built upon a newly created functional and reactive Swift architecture, it employs RxSwift for mastery over time-dependent operations. State handling is through an immutable model conforming to Codable with persistence to local storage. Remaining legacy dependencies are intended to be resolved with further updates.

## Features
- Example host apps for iOS and macOS
- Bundled block lists available by default
- Automatic downloading of remote block list sources
- New block list sources activated as soon as they are ready
- Rule list caching and downloads synchronized to user state
- Persistable user state to local storage
- Whitelistable domain names for users
- Fast switching of Acceptable Ads

## Installation
Tested with Xcode 10, RxSwift 4, iOS 12 and macOS 10.14 (Mojave).

### Building
- `git clone git@gitlab.com:eyeo/adblockplus/abpkit.git`
- `brew install carthage`
- `brew install swiftlint` (optional)
- `cd abpkit`
- `carthage update --platform="ios,macos"`
- `open ABPKit.xcodeproj`
- Build in Xcode

### Testing
Included unit tests verify correct results for many usages.

### Carthage
Add this line to your `Cartfile`:
```
git "https://gitlab.com/eyeo/adblockplus/abpkit" ~> 0.1
```

## Usage examples
### Content blocking in WKWebView
```swift
import ABPKit

class WebViewVC: ABPBlockable
{
    var abp: ABPWebViewBlocker!
    var webView: WKWebView!

    override func viewDidLoad()
    {
        let user = User()
        do { abp = try ABPWebViewBlocker(host: self, user: user) }
        catch let err { // Handle error }
    }
}
```

### Whitelisting
```swift
// Set
abp.user = abp.user.whitelistedDomainsSet()(["anydomain.com"])

// Get
let domains = abp.user.getWhiteListedDomains()
```

### Use content blocking sources automatically
```swift
// With current state in abp.user:
abp.useContentBlocking(completeWith:
{
    // Code to load URL
})
```

Content blocking starts with bundled block lists and is switched to downloaded block lists as soon as they are ready.

### User state persistence
```swift
// Persist user state
try abp.user.save()

// Persist state and return a copy
let saved = try abp.user.saved()

// Retrieve the last persisted state
let user = try User(fromPersistentStorage: true)
```

Most functionality is based on a given user state without requiring a persisted copy.

### Enable/Disable Acceptable Ads (AA)
```swift
// Enable
abp.user = abp.user.blockListSet()(BlockList(
    withAcceptableAds: true,
    source: RemoteBlockList.easylistPlusExceptions))

// Disable
abp.user = abp.user.blockListSet()(BlockList(
    withAcceptableAds: false,
    source: RemoteBlockList.easylist))
```

The new block list can be activated with `useContentBlocking(completeWith:)`.

### Verify AA usage
```swift
let aaInUse = abp.user.acceptableAdsInUse()
```

### Content Blocking on Safari for macOS
- Choose scheme `HostApp-macOS`
- Run in Xcode

The extension `HostCBExt-macOS` is installed to Safari. Content blocking in Safari can be activated by enabling the extension.

### Content Blocking on Safari for iOS
Not yet implemented.

## Release notes
v0.1 - Initial release. Supports content blocking in WKWebView on iOS and macOS.

## License
ABPKit is released as open source software under the GPL v3 license, see the `LICENSE.md` file in the project root for the full license text.
