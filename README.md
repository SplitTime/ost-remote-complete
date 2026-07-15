# OST Remote 2

iOS app for entering runner times into and out of aid stations at ultra
endurance events, feeding live data to [OpenSplitTime](https://www.opensplittime.org).

- **Bundle ID:** `com.OpenSplitTime.OST-Remote-2`
- **Minimum iOS:** 12.0 (iPhone and iPad)
- **Language:** Swift (with some retained Objective-C model/network code)
- **Dependencies:** none — no CocoaPods, no workspace

## Building

Open `OST Tracker.xcodeproj` in Xcode and use the **OST Remote 2** scheme.

```
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote 2" \
  -destination "platform=iOS Simulator,name=<any iPhone>" test
```

## History: classic OST Remote

This repository originally held the classic Objective-C **OST Remote**
(iOS 9+), distributed on the App Store under the bundle ID
`com.OpenSplitTime.OST-Remote`. Classic development ended when it became
impossible to test iOS 9 builds with modern Xcode and hardware.

- The **final released version** is App Store version **3.1.2**, built from
  the code preserved at tag [`v3.1.2`](../../releases/tag/v3.1.2) and branch
  [`ost-remote-final`](../../tree/ost-remote-final) (build uploaded
  March 23, 2022 — "Fix for iOS 9 network issue").
- Note the classic app's store version numbers (3.1.x) were maintained
  independently of the project's internal `MARKETING_VERSION` (3.6.x), and
  the About screen's version label was hardcoded. Do not expect them to
  correlate.
- An App Store Connect version record **3.1.3** was created but abandoned —
  never submitted, and containing no code beyond 3.1.2.

Everything after that point is **OST Remote 2**: a full front-end rewrite in
Swift by [Jon Eisen (@yanatan16)](https://github.com/yanatan16) (PR #10),
published as a separate App Store product so the classic app remains
available for iOS 9 devices.
