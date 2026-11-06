# Usage guide / 使用说明

This guide explains the main workflow in both English and Chinese. The
screenshot boxes are intentional placeholders: replace each box with a real
screen capture after the UI is finalized.

本文档提供中英文双语的主要操作说明。文中的截图框是有意保留的占位区域，等界面定稿后，把真实操作截图替换进去即可。

## 1. Build and launch / 构建与启动

**English**

Open `memoflick/memoflick.xcodeproj` in Xcode, choose the `memoflick` scheme,
configure your Team and unique Bundle ID, then run it on an iPhone or
simulator. The widget requires a matching App Group in both targets.

**中文**

使用 Xcode 打开 `memoflick/memoflick.xcodeproj`，选择 `memoflick` scheme，配置自己的 Team 和唯一 Bundle ID，然后在 iPhone 或模拟器上运行。小组件需要在两个 target 中配置一致的 App Group。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 构建操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/01-build-and-sign.png`
</td></tr></table>

## 2. Grant Photos access / 授予照片权限

**English**

On first launch, allow Photos access so the app can review local photos,
Live Photos, and videos. Full access is needed for a complete library review;
limited access can be used for a smaller selection.

**中文**

首次启动时，请授予照片访问权限，以便 App 读取本地照片、实况照片和视频。完整整理相册需要“所有照片”权限；也可以使用“选择照片”进行小范围体验。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 照片权限截图预留<br>
Suggested file / 建议文件：`docs/screenshots/02-photo-permission.png`
</td></tr></table>

## 3. Review photos / 整理照片

**English**

- Swipe left to move an item toward the trash workflow.
- Swipe right to keep an item.
- Use the favorite action to save an item and add a caption or category.

**中文**

- 左滑进入垃圾箱处理流程。
- 右滑保留照片。
- 使用收藏操作保存照片，并添加回忆文字或分类。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 照片操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/03-review-photos.png`
</td></tr></table>

## 4. Review videos / 整理视频

**English**

Open the video tab to browse local videos vertically. Keep, delete, favorite,
and share actions are available from the video review interface.

**中文**

进入视频 Tab 垂直浏览本地视频。在视频回顾界面中可以保留、删除、收藏或分享视频。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 视频操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/04-review-videos.png`
</td></tr></table>

## 5. Favorites and memories / 收藏与回忆

**English**

In the album area, open the favorites box to browse categories, media, and
captions. A favorite can keep the original media in Photos while storing the
review metadata locally.

**中文**

在相册区域打开收藏箱，可以按分类浏览媒体和回忆文字。收藏不会把原始媒体移出系统相册，整理元数据保存在本地。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 收藏操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/05-favorites-and-memories.png`
</td></tr></table>

## 6. Trash and recovery / 垃圾箱与恢复

**English**

Deleted items are tracked in the local trash history. Review the trash area to
restore an item or permanently delete it through Photos. Check the target
carefully before permanent deletion.

**中文**

删除的项目会记录在本地垃圾箱历史中。进入垃圾箱可以恢复项目，或通过 Photos 永久删除。执行永久删除前请仔细确认目标。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 垃圾箱操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/06-trash-and-recovery.png`
</td></tr></table>

## 7. Home-screen widget / 桌面小组件

**English**

Configure the photo-wall mode and background in the app, then add the
PhotoWall widget from the iPhone home-screen edit menu. The app and widget
must share the same App Group when you sign your fork.

**中文**

在 App 内配置照片墙模式和背景，然后从 iPhone 桌面编辑菜单添加 PhotoWall 小组件。给 fork 签名时，App 和小组件必须使用同一个 App Group。

<table><tr><td align="center" width="720" height="180">
📷 Screenshot placeholder / 小组件操作截图预留<br>
Suggested file / 建议文件：`docs/screenshots/07-home-screen-widget.png`
</td></tr></table>

## How to replace the screenshot slots / 如何替换截图占位

1. Capture a screenshot without personal photos, names, or other private data.
2. Save it using the suggested filename in `docs/screenshots/`.
3. Replace the matching placeholder table with:
   `![Description](screenshots/your-file.png)`.
4. Keep both the English and Chinese instructions when editing the guide.

1. 截取不含私人照片、姓名或其他隐私信息的操作图。
2. 使用建议文件名保存到 `docs/screenshots/`。
3. 将对应的占位表格替换成：`![说明](screenshots/你的文件.png)`。
4. 修改文档时请保留英文和中文说明。

See [`docs/screenshots/README.md`](docs/screenshots/README.md) for the naming
checklist and privacy reminders.

如需命名清单和隐私提醒，请查看 [`docs/screenshots/README.md`](docs/screenshots/README.md)。
