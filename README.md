# Memoflick for iOS

<p align="center">
  <img src="memoflick/memoflick/Assets.xcassets/BrandLogoLight.imageset/logo-light.png" alt="Memoflick logo" width="180">
</p>

<p align="center">A local-first way to revisit, review, and organize your memories.</p>

[![License: PolyForm Noncommercial](https://img.shields.io/badge/license-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)

Memoflick is an offline-first photo and video review app for iPhone. This
repository contains the source for the offline release and its home-screen
widget.

## What is included

- Local photo and video review workflows
- Local favorites, trash history, metadata, and settings
- Home-screen widget backed by the same on-device photo data
- English and Chinese localization
- No Memoflick account, application server, Supabase, subscription, or
  StoreKit dependency

Your media stays in the Photos library and app-local storage on your device.
The app is designed to remain useful without a Memoflick backend or an
internet connection when the required originals are already available
locally. Apple Photos may retrieve iCloud-backed originals when the system and
the app request allow it; that transfer is handled by Apple Photos and is not
an upload to a Memoflick server. See `PRIVACY.md` for the precise boundary.

## Build locally

1. Open `memoflick/memoflick.xcodeproj` in Xcode.
2. Select the `memoflick` scheme and an iPhone simulator or device.
3. For a fork, set your own Apple Developer Team, bundle identifiers, and App
   Group identifiers. The staging project uses `com.example.memoflick.app`
   placeholders; do not reuse Memoflick's publishing identifiers.
4. Build with Xcode. The project deployment target is iOS 16.6, but the
   current app shows an availability message and requires iOS 17.0 or later
   for normal use.

The project is unsigned in this repository. Signing, provisioning, and App
Store distribution are the responsibility of each fork owner.

## Install on a physical iPhone

This repository is not an installable IPA. To put the app on an iPhone, build
and run it from Xcode with your own signing identity.

1. Install Xcode on a Mac and open `memoflick/memoflick.xcodeproj`.
2. Connect the iPhone, unlock it, and approve the Mac if iOS asks to trust it.
3. In Xcode, open **Settings > Apple Accounts** and add the Apple Account that
   will sign the app.
4. Select the `memoflick` target, open **Signing & Capabilities**, enable
   **Automatically manage signing**, and choose your Team.
5. Replace the placeholder identifiers with unique identifiers that belong to
   your fork. For example, change the app bundle ID to
   `com.example.yourname.memoflick` and the widget bundle ID to a matching
   unique value.
6. If you keep the widget, create your own App Group and replace
   `group.com.example.memoflick.app` in both entitlements files and both
   `WidgetPhotoStore.swift` files. Also update the widget `kind` string to
   match your widget bundle identifier.
7. Select the iPhone as the run destination and click **Run**. The first build
   may take a few minutes while Xcode registers the device and creates signing
   profiles.
8. If iOS asks for Developer Mode, enable it at **Settings > Privacy &
   Security > Developer Mode**, restart the iPhone, and run the app again.

An Apple Account with a free Personal Team can install an app on its own test
devices, but the provisioning is temporary and must be renewed by rebuilding
and reinstalling periodically. Apple currently limits free provisioning to
three devices and profiles that expire after seven days. A paid Apple
Developer Program membership is normally needed for longer-lived development
signing and capabilities such as the App Group used by the widget. See
[Apple's device-running documentation](https://developer.apple.com/documentation/xcode/building-and-running-an-app)
for the current signing flow.

If you only need the core app and your Personal Team cannot sign the App Group,
temporarily remove or disable the `PhotoWallWidgetExtension` target and its App
Group capability. The widget will not be available in that configuration.

## Privacy boundary

The source is intended to keep user media and review metadata on-device. Read
[`PRIVACY.md`](PRIVACY.md) for the data-flow summary. Any future fork that
adds networking, analytics, cloud sync, accounts, or remote processing must
document that change clearly and obtain its own privacy and security review.

## License

The source code is available under the PolyForm Noncommercial License 1.0.0.
It permits personal, educational, research, hobby, and other noncommercial
use, subject to the terms in `LICENSE`.

The Memoflick name, logo, icon, screenshots, and other brand assets are not
licensed for reuse. See `TRADEMARKS.md` and `NOTICE.md`.

This is source-available software with a noncommercial restriction; it is not
an OSI-approved open-source license.

## Contributing

See `CONTRIBUTING.md` before opening an issue or pull request. In particular,
please keep the offline behavior intact and do not commit signing material,
private user data, or service credentials. All contributors are expected to
follow `CODE_OF_CONDUCT.md`.
