# Memoflick for iOS / Memoflick iOS 版

<p align="center">
  <img src="memoflick/memoflick/Assets.xcassets/BrandLogoLight.imageset/logo-light.png" alt="Memoflick logo" width="180">
</p>

<p align="center">A local-first way to revisit, review, and organize your memories.<br>以本地优先的方式，重温、整理和保存你的回忆。</p>

[![License: PolyForm Noncommercial](https://img.shields.io/badge/license-PolyForm%20Noncommercial-blue.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)

## Introduction / 项目介绍

**English**

Memoflick is an offline-first photo and video review app for iPhone. It
provides local photo and video review, favorites, trash recovery, metadata,
and a home-screen photo-wall widget.

**中文**

Memoflick 是一款面向 iPhone 的离线优先照片与视频整理应用，支持本地照片和视频回顾、收藏、垃圾箱恢复、元数据管理，以及桌面照片墙小组件。

The app has no Memoflick account, application server, Supabase, subscription,
or StoreKit dependency. When the required originals are already available on
the device, the core workflow can be used without an internet connection.
Apple Photos may retrieve iCloud-backed originals when the system and the app
request it; that is handled by Apple Photos and is not an upload to a
Memoflick server. See [`PRIVACY.md`](PRIVACY.md).

本版本不依赖 Memoflick 账号、应用服务器、Supabase、订阅或 StoreKit。需要的原始素材已经在设备本地时，核心流程可以在没有网络的情况下使用。若照片由 iCloud Photos 管理，Apple Photos 可能按系统和应用请求取回云端原图；这由 Apple Photos 处理，不是上传到 Memoflick 服务器。详见 [`PRIVACY.md`](PRIVACY.md)。

## Features / 功能

| English | 中文 |
| --- | --- |
| Local photo and video review | 本地照片与视频回顾 |
| Favorites, captions, categories, and trash recovery | 收藏、回忆文字、分类与垃圾箱恢复 |
| Home-screen photo-wall widget | 桌面照片墙小组件 |
| English and Chinese localization | 中英文界面 |
| No Memoflick backend or account | 不需要 Memoflick 后端或账号 |

## Usage guide / 使用说明

See [`USAGE.md`](USAGE.md) for a bilingual step-by-step guide. It includes
reserved screenshot slots for each operation so maintainers can add real app
screenshots later without rewriting the instructions.

请查看 [`USAGE.md`](USAGE.md) 获取中英文分步操作说明。文档已经为每个操作预留截图位置，后续把真实 App 截图放入 `docs/screenshots/` 即可替换。

## Build locally / 本地构建

### English

1. Open `memoflick/memoflick.xcodeproj` in Xcode.
2. Select the `memoflick` scheme and an iPhone simulator or device.
3. For a fork, set your own Apple Developer Team, bundle identifiers, and App
   Group identifiers. The project uses the public placeholder
   `com.example.memoflick.app`; do not reuse Memoflick's publishing identifiers.
4. The project deployment target is iOS 16.6, but the current app shows an
   availability message and requires iOS 17.0 or later for normal use.

The project is unsigned in this repository. Signing, provisioning, and App
Store distribution are the responsibility of each fork owner.

### 中文

1. 使用 Xcode 打开 `memoflick/memoflick.xcodeproj`。
2. 选择 `memoflick` scheme，以及 iPhone 模拟器或真机。
3. 如果你要创建 fork，请配置自己的 Apple Developer Team、Bundle ID 和
   App Group ID。本项目使用公开占位符 `com.example.memoflick.app`，不要复用
   Memoflick 的发布标识。
4. 工程部署目标为 iOS 16.6，但当前 App 在 iOS 17.0 以下会显示兼容性提示，正常使用建议 iOS 17.0 或更高版本。

本仓库不包含签名。签名、Provisioning Profile 和 App Store 发布由各 fork 维护者负责。

## Install on a physical iPhone / 安装到真机

This repository is not an installable IPA. Build and run it from Xcode with
your own signing identity.

本仓库不是可直接安装的 IPA，需要使用你自己的签名身份在 Xcode 中构建运行。

1. Install Xcode and open `memoflick/memoflick.xcodeproj` / 安装 Xcode 并打开工程。
2. Add your Apple Account in **Xcode > Settings > Apple Accounts** / 在 Xcode 设置中添加 Apple Account。
3. In **Signing & Capabilities**, enable automatic signing and choose your Team / 在签名设置中开启自动签名并选择 Team。
4. Replace the app and widget bundle identifiers with unique identifiers / 替换 App 和小组件的 Bundle ID。
5. If keeping the widget, create your own App Group and replace
   `group.com.example.memoflick.app` in both entitlements files and both
   `WidgetPhotoStore.swift` files / 如果保留小组件，请创建自己的 App Group，并同步替换两个 entitlements 文件和两个 `WidgetPhotoStore.swift` 中的标识。
6. Select the iPhone and click **Run** / 选择 iPhone 后点击运行。

## Privacy / 隐私

The source is intended to keep user media and review metadata on-device. Any
fork that adds networking, analytics, cloud sync, accounts, or remote
processing must update [`PRIVACY.md`](PRIVACY.md) and perform its own privacy
and security review.

本项目旨在让用户媒体和整理元数据留在设备上。任何增加网络、分析、云同步、账号或远程处理的 fork，都必须更新 [`PRIVACY.md`](PRIVACY.md)，并自行完成隐私与安全评估。

## License / 许可证

The source code is available under the PolyForm Noncommercial License 1.0.0.
The authoritative legal text is [`LICENSE`](LICENSE); it permits noncommercial
use only. The Memoflick name, logo, icon, screenshots, and other brand assets
are not automatically licensed for reuse. See [`NOTICE.md`](NOTICE.md),
[`TRADEMARKS.md`](TRADEMARKS.md), and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

源代码采用 PolyForm Noncommercial License 1.0.0。具有法律效力的许可证原文请以 [`LICENSE`](LICENSE) 为准，仅允许非商业使用。Memoflick 名称、Logo、图标、截图及其他品牌资源不自动授予复用权。请同时阅读 [`NOTICE.md`](NOTICE.md)、[`TRADEMARKS.md`](TRADEMARKS.md) 和 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

This is source-available software with a noncommercial restriction; it is not
an OSI-approved open-source license.

这是带有非商业限制的 source-available 软件，不是 OSI 认证的标准开源许可证。

## Contributing / 参与贡献

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
before opening an issue or pull request. Do not commit signing material,
private user data, or service credentials.

提交 Issue 或 Pull Request 前，请阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md) 和 [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)。不要提交签名材料、私人用户数据或服务凭据。
