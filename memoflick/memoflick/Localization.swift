//
//  Localization.swift
//  memoflick
//
//  Created by Codex on 2025/12/25.
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Hashable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var brandName: String {
        switch self {
        case .simplifiedChinese:
            return "回忆刷"
        default:
            return "Memoflick"
        }
    }

    static var deviceDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        if preferred.contains("zh") {
            return .simplifiedChinese
        }
        return .english
    }

    var nativeName: String {
        switch self {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

struct AppLocalizer {
    let language: AppLanguage

    var brandName: String {
        language.brandName
    }

    func text(_ key: L10n) -> String {
        switch (key, language) {
        case (.appRequiresIOS17, .english):
            return "Requires iOS 17 or later"
        case (.appRequiresIOS17, .simplifiedChinese):
            return "该版本需要 iOS 17 及以上"

        case (.developerTipsSectionTitle, .english):
            return "Notes"
        case (.developerTipsSectionTitle, .simplifiedChinese):
            return "提示"
        case (.developerTipsMessage, .english):
            return "Automatic filtering and threshold tuning are disabled in this build. Use the tools below to import test assets."
        case (.developerTipsMessage, .simplifiedChinese):
            return "当前版本暂未开启自动筛选或阈值调节功能，所有照片筛选均依赖手动滑动。需要导入测试照片时，可使用下方工具。"
        case (.developerThemeSectionTitle, .english):
            return "Theme"
        case (.developerThemeSectionTitle, .simplifiedChinese):
            return "主题"
        case (.developerThemePickerLabel, .english):
            return "Interface theme"
        case (.developerThemePickerLabel, .simplifiedChinese):
            return "界面主题"
        case (.developerTestToolsSectionTitle, .english):
            return "Testing"
        case (.developerTestToolsSectionTitle, .simplifiedChinese):
            return "测试工具"
        case (.developerUploadTestPhotos, .english):
            return "Import Test Photos"
        case (.developerUploadTestPhotos, .simplifiedChinese):
            return "上传测试照片"
        case (.developerNavigationTitle, .english):
            return "Developer Tools"
        case (.developerNavigationTitle, .simplifiedChinese):
            return "开发者工具"
        case (.settingsNavigationTitle, .english):
            return "Settings"
        case (.settingsNavigationTitle, .simplifiedChinese):
            return "设置"
        case (.photoWallSettingsSectionTitle, .english):
            return "Photo wall widget management"
        case (.photoWallSettingsSectionTitle, .simplifiedChinese):
            return "照片墙小组件管理"
        case (.photoWallOptionBackground, .english):
            return "Custom background"
        case (.photoWallOptionBackground, .simplifiedChinese):
            return "自定义背景"
        case (.photoWallOptionDaily, .english):
            return "Refresh daily"
        case (.photoWallOptionDaily, .simplifiedChinese):
            return "按天刷新相片"
        case (.photoWallOptionRandomOnce, .english):
            return "Random refresh once"
        case (.photoWallOptionRandomOnce, .simplifiedChinese):
            return "随机刷新一次"
        case (.photoWallOptionManual, .english):
            return "Pick photos manually"
        case (.photoWallOptionManual, .simplifiedChinese):
            return "自主选择相片"
        case (.photoWallBackgroundModalTitle, .english):
            return "Photo wall background"
        case (.photoWallBackgroundModalTitle, .simplifiedChinese):
            return "照片墙背景"
        case (.photoWallBackgroundModalMessage, .english):
            return "Choose a preset background or use your own photo."
        case (.photoWallBackgroundModalMessage, .simplifiedChinese):
            return "选择预设背景，或使用自己的照片作为背景。"
        case (.photoWallBackgroundBlackVelvet, .english):
            return "Black velvet"
        case (.photoWallBackgroundBlackVelvet, .simplifiedChinese):
            return "黑绒"
        case (.photoWallBackgroundWarmPaper, .english):
            return "Warm paper"
        case (.photoWallBackgroundWarmPaper, .simplifiedChinese):
            return "暖纸"
        case (.photoWallBackgroundGrayPaper, .english):
            return "White paper"
        case (.photoWallBackgroundGrayPaper, .simplifiedChinese):
            return "白纸"
        case (.photoWallBackgroundWood, .english):
            return "Newspaper"
        case (.photoWallBackgroundWood, .simplifiedChinese):
            return "报纸"
        case (.photoWallBackgroundPickPhoto, .english):
            return "Use a photo as background"
        case (.photoWallBackgroundPickPhoto, .simplifiedChinese):
            return "使用照片作为背景"
        case (.photoWallBackgroundCustomLabel, .english):
            return "Custom photo"
        case (.photoWallBackgroundCustomLabel, .simplifiedChinese):
            return "自定义照片"
        case (.photoWallBackgroundSaveFailed, .english):
            return "Failed to save background photo."
        case (.photoWallBackgroundSaveFailed, .simplifiedChinese):
            return "背景图片保存失败。"
        case (.photoWallCustomRefreshTitle, .english):
            return "Custom refresh"
        case (.photoWallCustomRefreshTitle, .simplifiedChinese):
            return "自定义刷新"
        case (.photoWallCustomRefreshHint, .english):
            return "Add the widget on Home Screen before adjusting the photo wall."
        case (.photoWallCustomRefreshHint, .simplifiedChinese):
            return "需在桌面新增组件再调整照片墙哦"
        case (.photoWallBackgroundCropTitle, .english):
            return "Crop background"
        case (.photoWallBackgroundCropTitle, .simplifiedChinese):
            return "裁剪背景"
        case (.photoWallBackgroundCropSquare, .english):
            return "Square 1:1"
        case (.photoWallBackgroundCropSquare, .simplifiedChinese):
            return "方形 1:1"
        case (.photoWallBackgroundCropWide, .english):
            return "Wide 2:1"
        case (.photoWallBackgroundCropWide, .simplifiedChinese):
            return "横向 2:1"
        case (.photoWallBackgroundCropHint, .english):
            return "Adjust both sizes for different widgets."
        case (.photoWallBackgroundCropHint, .simplifiedChinese):
            return "请分别调整方形与横向背景。"
        case (.photoWallDailyModalTitle, .english):
            return "Refresh photos daily?"
        case (.photoWallDailyModalTitle, .simplifiedChinese):
            return "是否按天刷新相片？"
        case (.photoWallDailyModalMessage, .english):
            return "The photo wall will update with a new batch each day."
        case (.photoWallDailyModalMessage, .simplifiedChinese):
            return "照片墙将每日自动更换一批新照片。"
        case (.photoWallRandomOnceModalTitle, .english):
            return "Randomize once?"
        case (.photoWallRandomOnceModalTitle, .simplifiedChinese):
            return "是否随机刷新一次？"
        case (.photoWallRandomOnceModalMessage, .english):
            return "A new batch will be generated when you close the app."
        case (.photoWallRandomOnceModalMessage, .simplifiedChinese):
            return "退出应用后将随机切换到下一批照片。"
        case (.photoWallManualModalTitle, .english):
            return "Pick photos"
        case (.photoWallManualModalTitle, .simplifiedChinese):
            return "选择照片"
        case (.photoWallManualModalMessage, .english):
            return "Choose 8 to 16 photos. 8 or 16 looks best."
        case (.photoWallManualModalMessage, .simplifiedChinese):
            return "请选择 8–16 张照片，8 或 16 张展示效果最佳。"
        case (.photoWallManualSelectButton, .english):
            return "Select photos"
        case (.photoWallManualSelectButton, .simplifiedChinese):
            return "选择照片"
        case (.photoWallManualInvalidCount, .english):
            return "Please select at least 8 photos."
        case (.photoWallManualInvalidCount, .simplifiedChinese):
            return "请选择至少 8 张照片。"
        case (.photoWallCurrentLabel, .english):
            return "Default"
        case (.photoWallCurrentLabel, .simplifiedChinese):
            return "默认"
        case (.photoWallRandomOncePending, .english):
            return "Pending"
        case (.photoWallRandomOncePending, .simplifiedChinese):
            return "已安排"
        case (.timeFilterEntryTitle, .english):
            return "Choose specifit time"
        case (.timeFilterEntryTitle, .simplifiedChinese):
            return "选择回忆时间"
        case (.timeFilterSettingsSectionTitle, .english):
            return "Time filter"
        case (.timeFilterSettingsSectionTitle, .simplifiedChinese):
            return "时间筛选"
        case (.timeFilterNavigationTitle, .english):
            return "Choose time"
        case (.timeFilterNavigationTitle, .simplifiedChinese):
            return "自由选择回忆时间"
        case (.timeFilterSectionTitle, .english):
            return "Choose months"
        case (.timeFilterSectionTitle, .simplifiedChinese):
            return "选择月份"
        case (.timeFilterLoadingTitle, .english):
            return "Loading months…"
        case (.timeFilterLoadingTitle, .simplifiedChinese):
            return "正在读取中…"
        case (.timeFilterLoadingMessage, .english):
            return "Fetching album dates, please wait."
        case (.timeFilterLoadingMessage, .simplifiedChinese):
            return "正在获取相册时间，请稍后。"
        case (.timeFilterEmptyMessage, .english):
            return "No available time range."
        case (.timeFilterEmptyMessage, .simplifiedChinese):
            return "暂无可用的时间段。"
        case (.timeFilterAllTime, .english):
            return "All time"
        case (.timeFilterAllTime, .simplifiedChinese):
            return "全部时间"
        case (.actionClearToRandom, .english):
            return "Clear selection (fully random)"
        case (.actionClearToRandom, .simplifiedChinese):
            return "取消选择（完全随机）"
        case (.actionSwitchToRandom, .english):
            return "Switch to fully random"
        case (.actionSwitchToRandom, .simplifiedChinese):
            return "恢复完全随机"
        case (.proRequiredTitle, .english):
            return "Pro feature"
        case (.proRequiredTitle, .simplifiedChinese):
            return "高级会员专属功能"
        case (.proRequiredMessageTimeFilter, .english):
            return "Time filtering is available for Pro members. Upgrade to unlock."
        case (.proRequiredMessageTimeFilter, .simplifiedChinese):
            return "选择特定月份回忆仅对高级会员开放。升级后即可解锁时间筛选。"
        case (.devUnlockTitle, .english):
            return "Enter developer password"
        case (.devUnlockTitle, .simplifiedChinese):
            return "输入开发者密码"
        case (.devUnlockPlaceholder, .english):
            return "Password"
        case (.devUnlockPlaceholder, .simplifiedChinese):
            return "密码"
        case (.devUnlockError, .english):
            return "Incorrect password."
        case (.devUnlockError, .simplifiedChinese):
            return "密码错误。"
        case (.developerLanguageSectionTitle, .english):
            return "Language"
        case (.developerLanguageSectionTitle, .simplifiedChinese):
            return "语言"
        case (.developerLanguagePickerLabel, .english):
            return "App language"
        case (.developerLanguagePickerLabel, .simplifiedChinese):
            return "界面语言"
        case (.developerLanguageAutoOption, .english):
            return "Auto (follow system)"
        case (.developerLanguageAutoOption, .simplifiedChinese):
            return "根据系统自动选择"
        case (.developerMockLoginTitle, .english):
            return "Mock login"
        case (.developerMockLoginTitle, .simplifiedChinese):
            return "模拟登录"
        case (.developerMockLoginToggleLabel, .english):
            return "Pretend user is signed in"
        case (.developerMockLoginToggleLabel, .simplifiedChinese):
            return "模拟用户已登录"
        case (.developerMockLoginDescription, .english):
            return "Toggles UI into the signed-in state without real authentication."
        case (.developerMockLoginDescription, .simplifiedChinese):
            return "无需真实登录即可切换到登录态界面，方便调试 UI。"
        case (.developerPremiumSectionTitle, .english):
            return "Membership simulation"
        case (.developerPremiumSectionTitle, .simplifiedChinese):
            return "会员状态模拟"
        case (.developerPremiumPickerLabel, .english):
            return "Premium status"
        case (.developerPremiumPickerLabel, .simplifiedChinese):
            return "会员状态"
        case (.developerPremiumDescription, .english):
            return "Force non-premium or premium UI for debugging. \"Follow real\" uses the actual entitlement."
        case (.developerPremiumDescription, .simplifiedChinese):
            return "可强制普通或高级会员界面，便于调试；“跟随真实”使用实际权益。"
        case (.developerPremiumBasicName, .english):
            return "Basic"
        case (.developerPremiumBasicName, .simplifiedChinese):
            return "普通"
        case (.developerPremiumProName, .english):
            return "Premium"
        case (.developerPremiumProName, .simplifiedChinese):
            return "高级"
        case (.developerPremiumFollowReal, .english):
            return "Follow real"
        case (.developerPremiumFollowReal, .simplifiedChinese):
            return "跟随真实"
        case (.developerAccountSectionTitle, .english):
            return "Account testing"
        case (.developerAccountSectionTitle, .simplifiedChinese):
            return "账户测试"
        case (.developerForceLogoutButton, .english):
            return "Force sign out"
        case (.developerForceLogoutButton, .simplifiedChinese):
            return "强制退出登录"
        case (.developerForceLogoutDescription, .english):
            return "Clears the local developer login state."
        case (.developerForceLogoutDescription, .simplifiedChinese):
            return "清除本地开发者登录状态。"
        case (.developerForceLogoutConfirmTitle, .english):
            return "Sign out now?"
        case (.developerForceLogoutConfirmTitle, .simplifiedChinese):
            return "确认退出登录？"
        case (.developerForceLogoutConfirmMessage, .english):
            return "This will return the app to the logged-out state."
        case (.developerForceLogoutConfirmMessage, .simplifiedChinese):
            return "将切换到未登录状态，便于重新登录测试。"

        case (.themeSystemName, .english):
            return "System"
        case (.themeSystemName, .simplifiedChinese):
            return "跟随系统"
        case (.themeLightName, .english):
            return "Light"
        case (.themeLightName, .simplifiedChinese):
            return "白色"
        case (.themeDarkName, .english):
            return "Dark"
        case (.themeDarkName, .simplifiedChinese):
            return "深色"

        case (.permissionTitle, .english):
            return "Need access to your media library"
        case (.permissionTitle, .simplifiedChinese):
            return "需要访问您的媒体库"
        case (.permissionMessage, .english):
            return "Open Settings > Privacy > Photos and allow \(brandName) to read your library."
        case (.permissionMessage, .simplifiedChinese):
            return "请前往系统设置 > 隐私 > 照片，授予 \(brandName) 读取权限以继续体验。"
        case (.permissionButton, .english):
            return "Open Settings"
        case (.permissionButton, .simplifiedChinese):
            return "前往设置"

        case (.tabPhotos, .english):
            return "Photos"
        case (.tabPhotos, .simplifiedChinese):
            return "相片"
        case (.tabVideos, .english):
            return "Videos"
        case (.tabVideos, .simplifiedChinese):
            return "视频"
        case (.tabAlbum, .english):
            return "Albums"
        case (.tabAlbum, .simplifiedChinese):
            return "相册"
        case (.tabProfile, .english):
            return "Profile"
        case (.tabProfile, .simplifiedChinese):
            return "我的"

        case (.headerTitlePhotos, .english):
            return "Memoflick"
        case (.headerTitlePhotos, .simplifiedChinese):
            return "回忆刷"
        case (.headerTitleAlbum, .english):
            return "My Albums"
        case (.headerTitleAlbum, .simplifiedChinese):
            return "我的相册"
        case (.headerTitleProfile, .english):
            return "Memory Control Center"
        case (.headerTitleProfile, .simplifiedChinese):
            return "回忆控制中枢"

        case (.collectionSearchPlaceholder, .english):
            return "Search collections"
        case (.collectionSearchPlaceholder, .simplifiedChinese):
            return "搜索收藏"
        case (.collectionNewButton, .english):
            return "New"
        case (.collectionNewButton, .simplifiedChinese):
            return "新建"
        case (.collectionEmptyTitle, .english):
            return "No collections yet"
        case (.collectionEmptyTitle, .simplifiedChinese):
            return "还没有收藏"
        case (.collectionEmptyMessage, .english):
            return "Create your first collection to start organizing your memories."
        case (.collectionEmptyMessage, .simplifiedChinese):
            return "创建你的第一个收藏，开始整理回忆。"
        case (.collectionEmptyAction, .english):
            return "Create New Collection"
        case (.collectionEmptyAction, .simplifiedChinese):
            return "创建新的收藏"
        case (.collectionEmptySyncAction, .english):
            return "Sync System Albums"
        case (.collectionEmptySyncAction, .simplifiedChinese):
            return "同步系统相册"
        case (.collectionSyncPromptTitle, .english):
            return "Sync system albums?"
        case (.collectionSyncPromptTitle, .simplifiedChinese):
            return "同步系统相册？"
        case (.collectionSyncPromptMessage, .english):
            return "We'll import your existing albums and sync new collections to Photos."
        case (.collectionSyncPromptMessage, .simplifiedChinese):
            return "将导入系统相册，并把新建收藏同步到相册。"
        case (.collectionSyncPromptConfirm, .english):
            return "Sync now"
        case (.collectionSyncPromptConfirm, .simplifiedChinese):
            return "同步"
        case (.collectionSyncPromptDecline, .english):
            return "Not now"
        case (.collectionSyncPromptDecline, .simplifiedChinese):
            return "暂不同步"
        case (.collectionNewModalTitle, .english):
            return "New Collection"
        case (.collectionNewModalTitle, .simplifiedChinese):
            return "新建收藏"
        case (.collectionNewModalMessage, .english):
            return "Enter a name for this collection to start organizing."
        case (.collectionNewModalMessage, .simplifiedChinese):
            return "输入名称，开始整理你的回忆。"
        case (.collectionNewModalPlaceholder, .english):
            return "e.g. Summer 2024"
        case (.collectionNewModalPlaceholder, .simplifiedChinese):
            return "例如：2024夏日"
        case (.collectionNewModalCancel, .english):
            return "Cancel"
        case (.collectionNewModalCancel, .simplifiedChinese):
            return "取消"
        case (.collectionNewModalCreate, .english):
            return "Create"
        case (.collectionNewModalCreate, .simplifiedChinese):
            return "创建"
        case (.collectionNewDefaultTitle, .english):
            return "Untitled Collection"
        case (.collectionNewDefaultTitle, .simplifiedChinese):
            return "未命名收藏"
        case (.collectionDetailEmptyTitle, .english):
            return "No photos or videos"
        case (.collectionDetailEmptyTitle, .simplifiedChinese):
            return "暂无照片或视频"
        case (.collectionDetailEmptyMessage, .english):
            return "There are no items in this collection yet."
        case (.collectionDetailEmptyMessage, .simplifiedChinese):
            return "这个收藏里暂时没有内容。"
        case (.collectionDetailEmptyAction, .english):
            return "Back to Home"
        case (.collectionDetailEmptyAction, .simplifiedChinese):
            return "返回主页"
        case (.collectionDetailBackButton, .english):
            return "Back"
        case (.collectionDetailBackButton, .simplifiedChinese):
            return "返回"
        case (.collectionDeleteTitle, .english):
            return "Delete this collection?"
        case (.collectionDeleteTitle, .simplifiedChinese):
            return "删除该相簿分类？"
        case (.collectionDeleteMessage, .english):
            return "This will only remove the collection category. Photos stay in your library."
        case (.collectionDeleteMessage, .simplifiedChinese):
            return "该操作只会删除相簿分类，不会删除照片。"
        case (.collectionCoverCustomizeAction, .english):
            return "Customize cover"
        case (.collectionCoverCustomizeAction, .simplifiedChinese):
            return "自定义封面"
        case (.collectionRenameAction, .english):
            return "Rename"
        case (.collectionRenameAction, .simplifiedChinese):
            return "重命名"
        case (.collectionRenameTitle, .english):
            return "Rename Collection"
        case (.collectionRenameTitle, .simplifiedChinese):
            return "重命名相簿"
        case (.collectionRenamePlaceholder, .english):
            return "New name"
        case (.collectionRenamePlaceholder, .simplifiedChinese):
            return "输入新名称"
        case (.collectionRenameEmptyError, .english):
            return "Name cannot be empty."
        case (.collectionRenameEmptyError, .simplifiedChinese):
            return "名称不能为空。"
        case (.collectionRenameDuplicateError, .english):
            return "A collection with this name already exists."
        case (.collectionRenameDuplicateError, .simplifiedChinese):
            return "已存在同名相簿。"
        case (.collectionCoverPickerTitle, .english):
            return "Choose cover"
        case (.collectionCoverPickerTitle, .simplifiedChinese):
            return "选择封面"
        case (.collectionCleanupTitle, .english):
            return "Duplicate empty albums detected"
        case (.collectionCleanupTitle, .simplifiedChinese):
            return "检测到重复空相簿"
        case (.collectionCleanupMessage, .english):
            return "Remove empty duplicates to keep one album per name. Photos stay in your library."
        case (.collectionCleanupMessage, .simplifiedChinese):
            return "清理重复的空相簿，仅保留一个分类，照片不会被删除。"
        case (.collectionCleanupAction, .english):
            return "Clean up"
        case (.collectionCleanupAction, .simplifiedChinese):
            return "清理"
        case (.collectionCleanupConfirm, .english):
            return "Clean up"
        case (.collectionCleanupConfirm, .simplifiedChinese):
            return "确认清理"
        case (.collectionUntitledSystemAlbum, .english):
            return "Untitled Album"
        case (.collectionUntitledSystemAlbum, .simplifiedChinese):
            return "未命名相册"
        case (.demoCollectionTitleOne, .english):
            return "Weekend Walks"
        case (.demoCollectionTitleOne, .simplifiedChinese):
            return "周末散步"
        case (.demoCollectionTitleTwo, .english):
            return "City Stories"
        case (.demoCollectionTitleTwo, .simplifiedChinese):
            return "城市故事"
        case (.demoCollectionTitleThree, .english):
            return "Food Diary"
        case (.demoCollectionTitleThree, .simplifiedChinese):
            return "美食日记"

        case (.profileHeroTitle, .english):
            return "Your memory control center"
        case (.profileHeroTitle, .simplifiedChinese):
            return "你的回忆控制中枢"
        case (.profileHeroSubtitle, .english):
            return "Clean, curate, and celebrate your past in one place."
        case (.profileHeroSubtitle, .simplifiedChinese):
            return "清理、珍藏、回味都在这一页。"
        case (.profileStatsCleared, .english):
            return "Space reclaimed"
        case (.profileStatsCleared, .simplifiedChinese):
            return "已清理空间"
        case (.profileStatsMemories, .english):
            return "Treasured memories"
        case (.profileStatsMemories, .simplifiedChinese):
            return "已珍藏回忆"
        case (.profileStatsStories, .english):
            return "Organized stories"
        case (.profileStatsStories, .simplifiedChinese):
            return "已整理故事"
        case (.profileStatsClearedHint, .english):
            return "Tap to review Trash"
        case (.profileStatsClearedHint, .simplifiedChinese):
            return "点击查看垃圾箱"
        case (.profileStatsMemoriesHint, .english):
            return "Everything you favorited"
        case (.profileStatsMemoriesHint, .simplifiedChinese):
            return "你珍藏的所有照片和视频"
        case (.profileStatsStoriesHint, .english):
            return "Tap to view today's memories"
        case (.profileStatsStoriesHint, .simplifiedChinese):
            return "点击查看你今日的回忆"
        case (.albumTodayTitleKept, .english):
            return "Today’s view"
        case (.albumTodayTitleKept, .simplifiedChinese):
            return "今日查看"
        case (.albumTodayTitleTrash, .english):
            return "Today’s clean-up"
        case (.albumTodayTitleTrash, .simplifiedChinese):
            return "今日清理"
        case (.albumTodaySummaryLabelKept, .english):
            return "Today curated"
        case (.albumTodaySummaryLabelKept, .simplifiedChinese):
            return "今日整理"
        case (.albumTodaySummaryLabelTrash, .english):
            return "Today cleaned"
        case (.albumTodaySummaryLabelTrash, .simplifiedChinese):
            return "今日清理"
        case (.albumTodayCountFormat, .english):
            return "%d items"
        case (.albumTodayCountFormat, .simplifiedChinese):
            return "%d张"
        case (.albumTodayCountWithSizeFormat, .english):
            return "Today cleaned %d items (%@)"
        case (.albumTodayCountWithSizeFormat, .simplifiedChinese):
            return "今日清理 %d张 (%@)"
        case (.albumTrashPendingNotice, .english):
            return "Today's deletions are not confirmed. Tap to open and confirm from the top-right."
        case (.albumTrashPendingNotice, .simplifiedChinese):
            return "今日删除未确认，请点击并在右上角选择是否删除"
        case (.profileAccountSectionTitle, .english):
            return "Account & Access"
        case (.profileAccountSectionTitle, .simplifiedChinese):
            return "账户与权益"
        case (.profileAccountLoggedOutTitle, .english):
            return "Not signed in"
        case (.profileAccountLoggedOutTitle, .simplifiedChinese):
            return "未登录"
        case (.profileAccountLoggedOutSubtitle, .english):
            return "Sign in to sync data and unlock premium features."
        case (.profileAccountLoggedOutSubtitle, .simplifiedChinese):
            return "登录以同步数据或解锁高级功能"
        case (.profileAccountAppleLogin, .english):
            return "Continue with Apple"
        case (.profileAccountAppleLogin, .simplifiedChinese):
            return "通过 Apple 登录"
        case (.profileAccountGoogleLogin, .english):
            return "Continue with Google"
        case (.profileAccountGoogleLogin, .simplifiedChinese):
            return "通过 Google 登录"
        case (.profileAccountEmailLogin, .english):
            return "Email & password"
        case (.profileAccountEmailLogin, .simplifiedChinese):
            return "邮箱与密码"
        case (.profileAccountInvite, .english):
            return "Enter activation code"
        case (.profileAccountInvite, .simplifiedChinese):
            return "输入激活码"
        case (.profileAccountUpgrade, .english):
            return "Upgrade to premium"
        case (.profileAccountUpgrade, .simplifiedChinese):
            return "升级到高级版"
        case (.profileAccountActions, .english):
            return "Account actions"
        case (.profileAccountActions, .simplifiedChinese):
            return "账户操作"
        case (.profileAccountSignOut, .english):
            return "Sign out"
        case (.profileAccountSignOut, .simplifiedChinese):
            return "退出帐号"
        case (.profileAccountDeleteAccount, .english):
            return "Delete account"
        case (.profileAccountDeleteAccount, .simplifiedChinese):
            return "注销帐号"
        case (.profileAccountSignOutConfirmTitle, .english):
            return "Sign out?"
        case (.profileAccountSignOutConfirmTitle, .simplifiedChinese):
            return "确认退出帐号？"
        case (.profileAccountSignOutConfirmMessage, .english):
            return "You can sign in again at any time."
        case (.profileAccountSignOutConfirmMessage, .simplifiedChinese):
            return "你可以随时再次登录。"
        case (.profileAccountDeleteConfirmTitle, .english):
            return "Delete account?"
        case (.profileAccountDeleteConfirmTitle, .simplifiedChinese):
            return "确认注销帐号？"
        case (.profileAccountDeleteConfirmMessage, .english):
            return "This will permanently delete your account and cannot be undone."
        case (.profileAccountDeleteConfirmMessage, .simplifiedChinese):
            return "该操作不可撤销，注销后无法恢复。"
        case (.profileAccountCancel, .english):
            return "Cancel"
        case (.profileAccountCancel, .simplifiedChinese):
            return "取消"
        case (.upgradeHeroTag, .english):
            return "PRO UPGRADE"
        case (.upgradeHeroTag, .simplifiedChinese):
            return "PRO 升级"
        case (.upgradeHeroTitle, .english):
            return "Unlock all premium features"
        case (.upgradeHeroTitle, .simplifiedChinese):
            return "解锁全部高级功能"
        case (.upgradeFeaturePhotosTitle, .english):
            return "Organize photo memories"
        case (.upgradeFeaturePhotosTitle, .simplifiedChinese):
            return "整理相片回忆"
        case (.upgradeFeaturePhotosSubtitle, .english):
            return "Unlimited daily cleanup for your best moments"
        case (.upgradeFeaturePhotosSubtitle, .simplifiedChinese):
            return "每天不限次数，智能整理珍贵瞬间"
        case (.upgradeFeatureVideosTitle, .english):
            return "Keep videos organized"
        case (.upgradeFeatureVideosTitle, .simplifiedChinese):
            return "整理视频回忆"
        case (.upgradeFeatureVideosSubtitle, .english):
            return "HD-friendly grouping with no usage limits"
        case (.upgradeFeatureVideosSubtitle, .simplifiedChinese):
            return "支持高清视频归档，无限制使用"
        case (.upgradeFeatureAdfreeTitle, .english):
            return "Ad-free experience"
        case (.upgradeFeatureAdfreeTitle, .simplifiedChinese):
            return "纯净无广告"
        case (.upgradeFeatureAdfreeSubtitle, .english):
            return "Stay focused with zero interruptions"
        case (.upgradeFeatureAdfreeSubtitle, .simplifiedChinese):
            return "沉浸体验，没有任何干扰"
        case (.upgradeFeatureOrganizeTitle, .english):
            return "Smart categories"
        case (.upgradeFeatureOrganizeTitle, .simplifiedChinese):
            return "轻松分类整理"
        case (.upgradeFeatureOrganizeSubtitle, .english):
            return "Custom albums keep everything in order"
        case (.upgradeFeatureOrganizeSubtitle, .simplifiedChinese):
            return "自定义相册归类，管理井井有条"
        case (.upgradeFeatureStorageTitle, .english):
            return "Save storage"
        case (.upgradeFeatureStorageTitle, .simplifiedChinese):
            return "节省存储空间"
        case (.upgradeFeatureStorageSubtitle, .english):
            return "Clear similar items to free up space"
        case (.upgradeFeatureStorageSubtitle, .simplifiedChinese):
            return "快速清理相似内容，释放手机内存"
        case (.upgradePlanYearlyTitle, .english):
            return "Yearly plan"
        case (.upgradePlanYearlyTitle, .simplifiedChinese):
            return "年度会员"
        case (.upgradePlanYearlySubtitle, .english):
            return "3-day free trial, then auto-renews"
        case (.upgradePlanYearlySubtitle, .simplifiedChinese):
            return "3天免费试用，之后自动续费"
        case (.upgradePlanYearlyPrice, .english):
            return "$4.99"
        case (.upgradePlanYearlyPrice, .simplifiedChinese):
            return "$4.99"
        case (.upgradePlanYearlyPeriod, .english):
            return "/ year"
        case (.upgradePlanYearlyPeriod, .simplifiedChinese):
            return "/ 年"
        case (.upgradePlanLifetimeTitle, .english):
            return "Lifetime access"
        case (.upgradePlanLifetimeTitle, .simplifiedChinese):
            return "终身会员"
        case (.upgradePlanLifetimeSubtitle, .english):
            return "One-time payment, keep forever"
        case (.upgradePlanLifetimeSubtitle, .simplifiedChinese):
            return "一次性付费，永久拥有"
        case (.upgradePlanLifetimePrice, .english):
            return "$12.99"
        case (.upgradePlanLifetimePrice, .simplifiedChinese):
            return "$12.99"
        case (.upgradePlanLifetimePeriod, .english):
            return "one-time"
        case (.upgradePlanLifetimePeriod, .simplifiedChinese):
            return "一次性"
        case (.upgradePlanBestValue, .english):
            return "Best value"
        case (.upgradePlanBestValue, .simplifiedChinese):
            return "最超值"
        case (.upgradeCTAFreeTrial, .english):
            return "Start 3-day Pro trial"
        case (.upgradeCTAFreeTrial, .simplifiedChinese):
            return "免费试用 3 天 Pro 权益"
        case (.upgradeCTALifetime, .english):
            return "Unlock Pro now"
        case (.upgradeCTALifetime, .simplifiedChinese):
            return "立即开启 Pro 体验"
        case (.upgradeRestorePurchase, .english):
            return "Restore purchases"
        case (.upgradeRestorePurchase, .simplifiedChinese):
            return "恢复购买"
        case (.upgradeTermsOfService, .english):
            return "Terms of Service"
        case (.upgradeTermsOfService, .simplifiedChinese):
            return "服务条款"
        case (.upgradePrivacyPolicy, .english):
            return "Privacy Policy"
        case (.upgradePrivacyPolicy, .simplifiedChinese):
            return "隐私政策"
        case (.upgradeSubscriptionNote, .english):
            return "Payment will be charged to your iTunes account. Subscription renews automatically unless you turn off auto-renew at least 24 hours before the current period ends."
        case (.upgradeSubscriptionNote, .simplifiedChinese):
            return "确认购买后将向您的 iTunes 账户收费。订阅将自动续期，除非在当前周期结束前至少 24 小时关闭自动续订。"
        case (.upgradeProductsUnavailable, .english):
            return "Products unavailable. Please try again soon."
        case (.upgradeProductsUnavailable, .simplifiedChinese):
            return "无法获取商品信息，请稍后重试。"
        case (.memberBasic, .english):
            return "Basic member"
        case (.memberBasic, .simplifiedChinese):
            return "普通会员"
        case (.memberPremium, .english):
            return "Premium member"
        case (.memberPremium, .simplifiedChinese):
            return "高级会员"
        case (.memberExpiryPrefix, .english):
            return "Expires: "
        case (.memberExpiryPrefix, .simplifiedChinese):
            return "到期："
        case (.memberLifetimeSuffix, .english):
            return " (lifetime)"
        case (.memberLifetimeSuffix, .simplifiedChinese):
            return "（永久）"
        case (.memberNoExpiry, .english):
            return "No expiry"
        case (.memberNoExpiry, .simplifiedChinese):
            return "无到期时间"
        case (.invitePlaceholder, .english):
            return "Enter your invite code"
        case (.invitePlaceholder, .simplifiedChinese):
            return "输入您的邀请码"
        case (.inviteSubmit, .english):
            return "Redeem"
        case (.inviteSubmit, .simplifiedChinese):
            return "兑换"
        case (.inviteSuccessMessage, .english):
            return "Invite redeemed! Premium unlocked."
        case (.inviteSuccessMessage, .simplifiedChinese):
            return "激活成功，已解锁高级会员。"
        case (.inviteInvalidMessage, .english):
            return "Invite code is invalid or already used."
        case (.inviteInvalidMessage, .simplifiedChinese):
            return "邀请码无效或已被使用。"
        case (.inviteEmptyError, .english):
            return "Please enter your invite code."
        case (.inviteEmptyError, .simplifiedChinese):
            return "请输入邀请码"
        case (.inviteLoginRequired, .english):
            return "Please sign in before redeeming an invite."
        case (.inviteLoginRequired, .simplifiedChinese):
            return "请先登录后再输入邀请码"
        case (.profileMoreSectionTitle, .english):
            return "More"
        case (.profileMoreSectionTitle, .simplifiedChinese):
            return "更多"
        case (.profileMoreHelp, .english):
            return "Help & feedback"
        case (.profileMoreHelp, .simplifiedChinese):
            return "帮助与反馈"
        case (.profileMoreAboutTitle, .english):
            return "About Memoflick"
        case (.profileMoreAboutTitle, .simplifiedChinese):
            return "关于回忆刷"
        case (.profileMoreAboutBody, .english):
            return """
Does this sound like you? Your phone is packed with thousands of photos, yet you rarely look back at them. They sit there in the dark corners of your storage, hogging space and gathering "digital dust."

MemoFlick was born to change exactly that.

We’ve transformed the tedious chore of "photo organization" into a fun, relaxing daily habit—just like scrolling through your favorite short videos. In just a few minutes a day, you can:

📱 Swipe Like You're on Social Media
Say goodbye to tedious tapping and selecting. Use the intuitive gestures you already love—swipe left, swipe right—to fly through piles of photos and videos at lightning speed.

✨ Your Daily Dose of Nostalgia
Our smart AI curates random moments from your past every day. Turn your spare seconds into surprise encounters with a younger you or a forgotten sunny day.

🧹 Effortlessly Reclaim Storage
Clear out screenshots, burst shots, and blurry duds while you reminisce. You'll double your available storage before you even realize it!

❤️ Keep Only What Matters
Turn your camera roll from a messy warehouse into a curated gallery. Every photo you keep becomes a story worth cherishing.
"""
        case (.profileMoreAboutBody, .simplifiedChinese):
            return """
你是不是也一样？手机里存了几万张照片，却很少有机会翻看。它们静静地躺在角落里，占用了空间，也积了灰尘。

MemoFlick（回忆刷）的诞生，就是为了改变这一切。

我们把枯燥的“整理相册”，变成了像刷短视频一样轻松有趣的日常。每天只需要几分钟，你可以：

📱 像刷抖音或者约会软件一样刷视频和照片
告别繁琐的点击和选择，用你最熟悉的“左滑右滑”“上滑下滑”手势，极速处理成堆的照片与视频。

✨ 每天一点“回忆杀”
智能算法每天为你随机推送过往瞬间。在碎片时间里，也能偶遇多年前的惊喜。

🧹 轻松释放手机空间
在重温回忆的同时，顺手清理截图、连拍和模糊废片。不知不觉，手机空间大了一倍！

❤️ 只留最珍贵的
让相册从“仓库”变成“画廊”。每一张留下的，都是值得珍藏的故事。
"""
        case (.profileMoreAbout, .english):
            return "About \(brandName)"
        case (.profileMoreAbout, .simplifiedChinese):
            return "关于 \(brandName)"

        case (.profileLockedTitle, .english):
            return "Account center opens in v0.3"
        case (.profileLockedTitle, .simplifiedChinese):
            return "账户中心将在 v0.3 开放"
        case (.profileLockedMessage, .english):
            return "Invites, analytics, and rewards are coming soon."
        case (.profileLockedMessage, .simplifiedChinese):
            return "敬请期待邀请码、统计面板与激励体系。"

        case (.subtitlePhotosScanning, .english):
            return "Scanning your photo library..."
        case (.subtitlePhotosScanning, .simplifiedChinese):
            return "正在扫描照片库..."
        case (.subtitleVideosScanning, .english):
            return "Scanning your video library..."
        case (.subtitleVideosScanning, .simplifiedChinese):
            return "正在扫描视频库..."
        case (.subtitlePermissionNeeded, .english):
            return "Photo permission required"
        case (.subtitlePermissionNeeded, .simplifiedChinese):
            return "需要照片权限以继续"
        case (.subtitleSwipeHint, .english):
            return "Swipe left/right to triage quickly"
        case (.subtitleSwipeHint, .simplifiedChinese):
            return "左右滑动快速筛掉废片"

        case (.photoScanBackgroundTitle, .english):
            return "Background scan in progress"
        case (.photoScanBackgroundTitle, .simplifiedChinese):
            return "后台扫描进行中"
        case (.photoScanPlaceholderTitle, .english):
            return "Scanning your photo library"
        case (.photoScanPlaceholderTitle, .simplifiedChinese):
            return "正在扫描您的照片库"
        case (.photoScanPlaceholderMessage, .english):
            return "The first scan happens once; after that everything is instant."
        case (.photoScanPlaceholderMessage, .simplifiedChinese):
            return "首次扫描只需等待一次，之后即可极速滑动。"
        case (.photoEmptyTitle, .english):
            return "No more photos to clean up"
        case (.photoEmptyTitle, .simplifiedChinese):
            return "没有更多待清理的照片啦"
        case (.photoEmptyMessage, .english):
            return "Come back later or tweak the top-right threshold to explore more candidates."
        case (.photoEmptyMessage, .simplifiedChinese):
            return "可以稍后再来，或尝试调整右上角的阈值以探索更多候选。"
        case (.photoTimeFilterEmptyTitle, .english):
            return "No more photos for this month"
        case (.photoTimeFilterEmptyTitle, .simplifiedChinese):
            return "该月份暂无更多待处理照片"
        case (.photoTimeFilterEmptySubtitle, .english):
            return "Try another month or switch to fully random to keep swiping."
        case (.photoTimeFilterEmptySubtitle, .simplifiedChinese):
            return "可以尝试其他月份，或选择完全随机来继续刷照片。"
        case (.photoGroupCompleteTitle, .english):
            return "This set of photos is done. Continue?"
        case (.photoGroupCompleteTitle, .simplifiedChinese):
            return "该组照片已刷完，是否要继续？"
        case (.videoGroupCompleteTitle, .english):
            return "This set of videos is organized. Continue?"
        case (.videoGroupCompleteTitle, .simplifiedChinese):
            return "该组视频已整理完，是否要继续？"
        case (.groupDailyLimitReached, .english):
            return "You've reached today's limit."
        case (.groupDailyLimitReached, .simplifiedChinese):
            return "今日可刷组数已用完。"
        case (.limitPhotoRemainingTitle, .english):
            return "This set of photos is done"
        case (.limitPhotoRemainingTitle, .simplifiedChinese):
            return "本组照片已完成"
        case (.limitVideoRemainingTitle, .english):
            return "This set of videos is done"
        case (.limitVideoRemainingTitle, .simplifiedChinese):
            return "本组视频已完成"
        case (.limitExhaustedTitle, .english):
            return "Today's quota is used up"
        case (.limitExhaustedTitle, .simplifiedChinese):
            return "今日额度已用完"
        case (.limitExhaustedSubtitlePhoto, .english):
            return "Upgrade to Pro for unlimited photo cleanup."
        case (.limitExhaustedSubtitlePhoto, .simplifiedChinese):
            return "升级 Pro，享受无限照片清理。"
        case (.limitExhaustedSubtitleVideo, .english):
            return "Upgrade to Pro for unlimited video cleanup."
        case (.limitExhaustedSubtitleVideo, .simplifiedChinese):
            return "升级 Pro，享受无限视频清理。"
        case (.limitPremiumSubtitle, .english):
            return "You're Pro. Keep cleaning as much as you like."
        case (.limitPremiumSubtitle, .simplifiedChinese):
            return "你已是高级会员，可无限继续整理。"
        case (.limitGroupCleared, .english):
            return "Cleared this set: %@"
        case (.limitGroupCleared, .simplifiedChinese):
            return "本组已清理：%@"
        case (.limitCTAReviewTrash, .english):
            return "Review today's deleted memories"
        case (.limitCTAReviewTrash, .simplifiedChinese):
            return "去确认今日删除回忆"
        case (.limitCTAUpgradePro, .english):
            return "Upgrade to Pro"
        case (.limitCTAUpgradePro, .simplifiedChinese):
            return "立即升级 Pro"
        case (.limitBenefitUnlimitedPhotos, .english):
            return "Unlimited photo cleanup"
        case (.limitBenefitUnlimitedPhotos, .simplifiedChinese):
            return "无限照片清理"
        case (.limitBenefitUnlimitedVideos, .english):
            return "Unlimited video cleanup"
        case (.limitBenefitUnlimitedVideos, .simplifiedChinese):
            return "无限视频清理"
        case (.limitBenefitEarlyAccess, .english):
            return "Early access to new features"
        case (.limitBenefitEarlyAccess, .simplifiedChinese):
            return "新功能优先体验"
        case (.actionRescan, .english):
            return "Rescan"
        case (.actionRescan, .simplifiedChinese):
            return "重新扫描"
        case (.actionContinue, .english):
            return "Next set"
        case (.actionContinue, .simplifiedChinese):
            return "再来一组"
        case (.actionLater, .english):
            return "Maybe later"
        case (.actionLater, .simplifiedChinese):
            return "稍后再刷"
        case (.previewRequiresIOS17, .english):
            return "Preview requires iOS 17+"
        case (.previewRequiresIOS17, .simplifiedChinese):
            return "预览需要 iOS 17+"

        case (.actionDelete, .english):
            return "Delete"
        case (.actionDelete, .simplifiedChinese):
            return "删除"
        case (.actionCancel, .english):
            return "Cancel"
        case (.actionCancel, .simplifiedChinese):
            return "取消"
        case (.actionConfirm, .english):
            return "Confirm"
        case (.actionConfirm, .simplifiedChinese):
            return "确认"
        case (.actionDone, .english):
            return "Done"
        case (.actionDone, .simplifiedChinese):
            return "完成"
        case (.actionSelect, .english):
            return "Select"
        case (.actionSelect, .simplifiedChinese):
            return "选择"
        case (.actionRestore, .english):
            return "Restore"
        case (.actionRestore, .simplifiedChinese):
            return "恢复"
        case (.actionSelectAll, .english):
            return "Select All"
        case (.actionSelectAll, .simplifiedChinese):
            return "全选"
        case (.actionUnselectAll, .english):
            return "Clear All"
        case (.actionUnselectAll, .simplifiedChinese):
            return "取消全选"
        case (.actionUpgrade, .english):
            return "Upgrade"
        case (.actionUpgrade, .simplifiedChinese):
            return "去升级"
        case (.actionLogin, .english):
            return "Sign in"
        case (.actionLogin, .simplifiedChinese):
            return "去登录"
        case (.limitLoginHint, .english):
            return "Sign in before upgrading is recommended."
        case (.limitLoginHint, .simplifiedChinese):
            return "建议先登录再升级"
        case (.actionMoveToTrash, .english):
            return "Move to Trash"
        case (.actionMoveToTrash, .simplifiedChinese):
            return "移至垃圾箱"
        case (.actionGoToSettings, .english):
            return "Open Settings"
        case (.actionGoToSettings, .simplifiedChinese):
            return "前往设置"
        case (.actionAdd, .english):
            return "Add"
        case (.actionAdd, .simplifiedChinese):
            return "添加"
        case (.actionFavorite, .english):
            return "Favorite"
        case (.actionFavorite, .simplifiedChinese):
            return "收藏"
        case (.actionShare, .english):
            return "Share"
        case (.actionShare, .simplifiedChinese):
            return "分享"

        case (.albumTabKept, .english):
            return "Kept"
        case (.albumTabKept, .simplifiedChinese):
            return "已查看"
        case (.albumTabCollections, .english):
            return "Collections"
        case (.albumTabCollections, .simplifiedChinese):
            return "收藏夹"
        case (.albumTabTrash, .english):
            return "Trash"
        case (.albumTabTrash, .simplifiedChinese):
            return "垃圾箱"
        case (.albumDeleteConfirmationTitle, .english):
            return "Delete the selected items?"
        case (.albumDeleteConfirmationTitle, .simplifiedChinese):
            return "确定要删除所选内容吗？"
        case (.albumGridEmptyKept, .english):
            return "No kept items yet"
        case (.albumGridEmptyKept, .simplifiedChinese):
            return "暂无已查看内容"
        case (.albumGridEmptyTrash, .english):
            return "Trash is empty"
        case (.albumGridEmptyTrash, .simplifiedChinese):
            return "垃圾箱为空"
        case (.albumSelectionPrompt, .english):
            return "Select items"
        case (.albumSelectionPrompt, .simplifiedChinese):
            return "请选择内容"
        case (.albumFolderHint, .english):
            return "Tap to open memories"
        case (.albumFolderHint, .simplifiedChinese):
            return "点击打开回忆"
        case (.albumCollectionEmptyTitle, .english):
            return "No favorites yet"
        case (.albumCollectionEmptyTitle, .simplifiedChinese):
            return "还没有收藏内容"
        case (.albumCollectionEmptyMessage, .english):
            return "Tap Favorite in Photos or Videos to fill this space."
        case (.albumCollectionEmptyMessage, .simplifiedChinese):
            return "去相片或视频模块点击“收藏”按钮，解锁属于你的回忆盒。"
        case (.albumCategoryEmptyMessage, .english):
            return "This category is empty"
        case (.albumCategoryEmptyMessage, .simplifiedChinese):
            return "该分类暂无内容"
        case (.albumCollectionBackButton, .english):
            return "Back to categories"
        case (.albumCollectionBackButton, .simplifiedChinese):
            return "返回分类"

        case (.favoriteComposerPrimaryTitle, .english):
            return "Add to favorites"
        case (.favoriteComposerPrimaryTitle, .simplifiedChinese):
            return "加入收藏"
        case (.favoriteComposerTitle, .english):
            return "Add to a collection"
        case (.favoriteComposerTitle, .simplifiedChinese):
            return "收藏到分类"
        case (.favoriteComposerPickerTitle, .english):
            return "Choose a category"
        case (.favoriteComposerPickerTitle, .simplifiedChinese):
            return "选择分类"
        case (.favoriteComposerNewSectionTitle, .english):
            return "Create new category"
        case (.favoriteComposerNewSectionTitle, .simplifiedChinese):
            return "新建分类"
        case (.favoriteComposerNewButton, .english):
            return "New"
        case (.favoriteComposerNewButton, .simplifiedChinese):
            return "新建"
        case (.favoriteComposerConfirmNewButton, .english):
            return "Confirm"
        case (.favoriteComposerConfirmNewButton, .simplifiedChinese):
            return "确定"
        case (.favoriteComposerNamePlaceholder, .english):
            return "Enter a category name"
        case (.favoriteComposerNamePlaceholder, .simplifiedChinese):
            return "输入分类名称"
        case (.favoriteComposerAddButton, .english):
            return "Add"
        case (.favoriteComposerAddButton, .simplifiedChinese):
            return "添加"
        case (.favoriteComposerCaptionTitle, .english):
            return "Memory notes (optional)"
        case (.favoriteComposerCaptionTitle, .simplifiedChinese):
            return "回忆日记（选填）"
        case (.favoriteComposerCaptionPlaceholder, .english):
            return "Leave a short note about the moment…"
        case (.favoriteComposerCaptionPlaceholder, .simplifiedChinese):
            return "写点当时的心情吧…"
        case (.favoriteComposerSaveButton, .english):
            return "Save"
        case (.favoriteComposerSaveButton, .simplifiedChinese):
            return "保存"

        case (.photoTutorialTitle, .english):
            return "Quick tour for photos"
        case (.photoTutorialTitle, .simplifiedChinese):
            return "照片快速教学"
        case (.photoTutorialSubtitle, .english):
            return "Three gestures to delete, keep, or favorite."
        case (.photoTutorialSubtitle, .simplifiedChinese):
            return "三种手势：左丢弃、右保留、上收藏。"
        case (.photoTutorialStepLeftTitle, .english):
            return "Swipe left Trash"
        case (.photoTutorialStepLeftTitle, .simplifiedChinese):
            return "左滑 丢进垃圾桶"
        case (.photoTutorialStepLeftDescription, .english):
            return "Remove photos you don't want and free up space."
        case (.photoTutorialStepLeftDescription, .simplifiedChinese):
            return "不喜欢的直接丢掉，释放空间。"
        case (.photoTutorialStepRightTitle, .english):
            return "Swipe right Keep"
        case (.photoTutorialStepRightTitle, .simplifiedChinese):
            return "右滑 已查看/跳过"
        case (.photoTutorialStepRightDescription, .english):
            return "Keep it or just move on without changes."
        case (.photoTutorialStepRightDescription, .simplifiedChinese):
            return "暂时保留或略过，不会改变状态。"
        case (.photoTutorialStepUpTitle, .english):
            return "Swipe up Favorite"
        case (.photoTutorialStepUpTitle, .simplifiedChinese):
            return "上滑 收藏分类"
        case (.photoTutorialStepUpDescription, .english):
            return "Mark the best shots and add notes/categories."
        case (.photoTutorialStepUpDescription, .simplifiedChinese):
            return "喜欢的加星并填写分类/备注。"
        case (.photoTutorialControlsHint, .english):
            return "Bottom buttons do the same actions."
        case (.photoTutorialControlsHint, .simplifiedChinese):
            return "底部按钮也能完成同样操作。"
        case (.photoTutorialNext, .english):
            return "Next"
        case (.photoTutorialNext, .simplifiedChinese):
            return "下一步"
        case (.photoTutorialStart, .english):
            return "Start reviewing"
        case (.photoTutorialStart, .simplifiedChinese):
            return "开始体验"
        case (.photoTutorialSkip, .english):
            return "Skip for now"
        case (.photoTutorialSkip, .simplifiedChinese):
            return "稍后再说"
        case (.photoTutorialSettingsSectionTitle, .english):
            return "Tutorial"
        case (.photoTutorialSettingsSectionTitle, .simplifiedChinese):
            return "新手指引"
        case (.photoTutorialReplayButton, .english):
            return "Replay photo tutorial"
        case (.photoTutorialReplayButton, .simplifiedChinese):
            return "重新查看照片教程"

        case (.videoSwipeHint, .english):
            return "Swipe up for next · down for previous"
        case (.videoSwipeHint, .simplifiedChinese):
            return "上滑播放下一条 · 下滑返回上一条"
        case (.videoTutorialSwipeUp, .english):
            return "Swipe up → next video"
        case (.videoTutorialSwipeUp, .simplifiedChinese):
            return "上滑 → 下一条"
        case (.videoTutorialSwipeDown, .english):
            return "Swipe down → previous video"
        case (.videoTutorialSwipeDown, .simplifiedChinese):
            return "下滑 → 上一条"
        case (.videoTutorialControlsTitle, .english):
            return "Right-side buttons control more actions"
        case (.videoTutorialControlsTitle, .simplifiedChinese):
            return "右侧按钮也可以快速操作"
        case (.videoTutorialFavoriteDetail, .english):
            return "Save and categorize this memory"
        case (.videoTutorialFavoriteDetail, .simplifiedChinese):
            return "点击收藏并分类"
        case (.videoTutorialDeleteDetail, .english):
            return "Move to the trash bin"
        case (.videoTutorialDeleteDetail, .simplifiedChinese):
            return "移入垃圾箱"
        case (.videoTutorialShareDetail, .english):
            return "Share this clip with friends"
        case (.videoTutorialShareDetail, .simplifiedChinese):
            return "转发给朋友"
        case (.videoTutorialGotIt, .english):
            return "Got it"
        case (.videoTutorialGotIt, .simplifiedChinese):
            return "我知道了"
        case (.videoTutorialEnableAudio, .english):
            return "Enable sound"
        case (.videoTutorialEnableAudio, .simplifiedChinese):
            return "确认打开音量"
        case (.videoScanPlaceholderTitle, .english):
            return "Scanning your video library"
        case (.videoScanPlaceholderTitle, .simplifiedChinese):
            return "正在扫描您的视频库"
        case (.videoScanPlaceholderMessage, .english):
            return "We load 100 clips to start; the rest continues in the background."
        case (.videoScanPlaceholderMessage, .simplifiedChinese):
            return "先加载 100 条即可开始上滑，剩余部分交给后台。"
        case (.videoEmptyTitle, .english):
            return "No videos awaiting review"
        case (.videoEmptyTitle, .simplifiedChinese):
            return "暂无待处理视频"
        case (.videoEmptyMessage, .english):
            return "Come back later or add favorites in Photos to unlock more video picks."
        case (.videoEmptyMessage, .simplifiedChinese):
            return "可以稍后再来，或在“相片”模块里添加收藏触发更多视频推荐。"
        case (.videoTimeFilterEmptyTitle, .english):
            return "No more videos for this month"
        case (.videoTimeFilterEmptyTitle, .simplifiedChinese):
            return "该月份暂无更多待处理视频"
        case (.videoTimeFilterEmptySubtitle, .english):
            return "Try another month or switch to fully random to keep swiping."
        case (.videoTimeFilterEmptySubtitle, .simplifiedChinese):
            return "可以尝试其他月份，或选择完全随机来继续刷视频。"
        case (.videoScanBackgroundTitle, .english):
            return "Background video scan in progress"
        case (.videoScanBackgroundTitle, .simplifiedChinese):
            return "后台视频扫描中"

        case (.mediaUnknownTimestamp, .english):
            return "Unknown capture time"
        case (.mediaUnknownTimestamp, .simplifiedChinese):
            return "未知拍摄时间"

        case (.favoriteDefaultCategory, .english):
            return "Untitled Category"
        case (.favoriteDefaultCategory, .simplifiedChinese):
            return "未命名分类"
        default:
            return "[missing: \(key)]"
        }
    }

    func albumSelectionStatus(count: Int) -> String {
        if count == 0 {
            return text(.albumSelectionPrompt)
        }
        switch language {
        case .english:
            return count == 1 ? "Selected 1 item" : "Selected \(count) items"
        case .simplifiedChinese:
            return "已选择 \(count) 项"
        }
    }

    func albumItemsCount(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 item" : "\(count) items"
        case .simplifiedChinese:
            return "\(count) 项"
        }
    }

    func albumMemoriesCount(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 memory" : "\(count) memories"
        case .simplifiedChinese:
            return "\(count) 个回忆"
        }
    }

    func groupUsageStatus(used: Int, limit: Int) -> String {
        switch language {
        case .english:
            return "Today: \(used)/\(limit) sets"
        case .simplifiedChinese:
            return "今日 \(used)/\(limit) 组"
        }
    }

    func limitTitle(isPhoto: Bool, hasRemainingQuota: Bool) -> String {
        if hasRemainingQuota {
            return isPhoto ? text(.limitPhotoRemainingTitle) : text(.limitVideoRemainingTitle)
        } else {
            return text(.limitExhaustedTitle)
        }
    }

    func limitSubtitle(isPhoto: Bool, hasRemainingQuota: Bool, dailyLimit: Int) -> String {
        switch language {
        case .english:
            if hasRemainingQuota {
                return isPhoto
                    ? "Free users can review up to \(dailyLimit) photo sets per day."
                    : "Free users can review up to \(dailyLimit) video sets per day."
            } else {
                return isPhoto ? text(.limitExhaustedSubtitlePhoto) : text(.limitExhaustedSubtitleVideo)
            }
        case .simplifiedChinese:
            if hasRemainingQuota {
                return isPhoto
                    ? "普通用户每日最多整理 \(dailyLimit) 组照片。"
                    : "普通用户每日最多整理 \(dailyLimit) 组视频。"
            } else {
                return isPhoto ? text(.limitExhaustedSubtitlePhoto) : text(.limitExhaustedSubtitleVideo)
            }
        }
    }

    func limitPremiumSubtitle() -> String {
        text(.limitPremiumSubtitle)
    }

    func limitGroupClearedText(_ formattedBytes: String) -> String {
        text(.limitGroupCleared).replacingOccurrences(of: "%@", with: formattedBytes)
    }
}

enum L10n {
    case appRequiresIOS17
    case developerTipsSectionTitle
    case developerTipsMessage
    case developerThemeSectionTitle
    case developerThemePickerLabel
    case developerTestToolsSectionTitle
    case developerUploadTestPhotos
    case developerNavigationTitle
    case developerLanguageSectionTitle
    case developerLanguagePickerLabel
    case developerLanguageAutoOption
    case developerMockLoginTitle
    case developerMockLoginToggleLabel
    case developerMockLoginDescription
    case developerPremiumSectionTitle
    case developerPremiumPickerLabel
    case developerPremiumDescription
    case developerPremiumBasicName
    case developerPremiumProName
    case developerPremiumFollowReal
    case developerAccountSectionTitle
    case developerForceLogoutButton
    case developerForceLogoutDescription
    case developerForceLogoutConfirmTitle
    case developerForceLogoutConfirmMessage
    case settingsNavigationTitle
    case photoWallSettingsSectionTitle
    case photoWallOptionBackground
    case photoWallOptionDaily
    case photoWallOptionRandomOnce
    case photoWallOptionManual
    case photoWallBackgroundModalTitle
    case photoWallBackgroundModalMessage
    case photoWallBackgroundBlackVelvet
    case photoWallBackgroundWarmPaper
    case photoWallBackgroundGrayPaper
    case photoWallBackgroundWood
    case photoWallBackgroundPickPhoto
    case photoWallBackgroundCustomLabel
    case photoWallBackgroundSaveFailed
    case photoWallBackgroundCropTitle
    case photoWallBackgroundCropSquare
    case photoWallBackgroundCropWide
    case photoWallBackgroundCropHint
    case photoWallCustomRefreshTitle
    case photoWallCustomRefreshHint
    case photoWallDailyModalTitle
    case photoWallDailyModalMessage
    case photoWallRandomOnceModalTitle
    case photoWallRandomOnceModalMessage
    case photoWallManualModalTitle
    case photoWallManualModalMessage
    case photoWallManualSelectButton
    case photoWallManualInvalidCount
    case photoWallCurrentLabel
    case photoWallRandomOncePending
    case actionConfirm
    case devUnlockTitle
    case devUnlockPlaceholder
    case devUnlockError
    case timeFilterSettingsSectionTitle
    case themeSystemName
    case themeLightName
    case themeDarkName
    case permissionTitle
    case permissionMessage
    case permissionButton
    case tabPhotos
    case tabVideos
    case tabAlbum
    case tabProfile
    case headerTitlePhotos
    case headerTitleAlbum
    case headerTitleProfile
    case collectionSearchPlaceholder
    case collectionNewButton
    case collectionEmptyTitle
    case collectionEmptyMessage
    case collectionEmptyAction
    case collectionEmptySyncAction
    case collectionSyncPromptTitle
    case collectionSyncPromptMessage
    case collectionSyncPromptConfirm
    case collectionSyncPromptDecline
    case collectionNewModalTitle
    case collectionNewModalMessage
    case collectionNewModalPlaceholder
    case collectionNewModalCancel
    case collectionNewModalCreate
    case collectionNewDefaultTitle
    case collectionDetailEmptyTitle
    case collectionDetailEmptyMessage
    case collectionDetailEmptyAction
    case collectionDetailBackButton
    case collectionDeleteTitle
    case collectionDeleteMessage
    case collectionCoverCustomizeAction
    case collectionRenameAction
    case collectionRenameTitle
    case collectionRenamePlaceholder
    case collectionRenameEmptyError
    case collectionRenameDuplicateError
    case collectionCoverPickerTitle
    case collectionCleanupTitle
    case collectionCleanupMessage
    case collectionCleanupAction
    case collectionCleanupConfirm
    case collectionUntitledSystemAlbum
    case demoCollectionTitleOne
    case demoCollectionTitleTwo
    case demoCollectionTitleThree
    case profileHeroTitle
    case profileHeroSubtitle
    case profileStatsCleared
    case profileStatsMemories
    case profileStatsStories
    case profileStatsClearedHint
    case profileStatsMemoriesHint
    case profileStatsStoriesHint
    case albumTodayTitleKept
    case albumTodayTitleTrash
    case albumTodaySummaryLabelKept
    case albumTodaySummaryLabelTrash
    case albumTodayCountFormat
    case albumTodayCountWithSizeFormat
    case albumTrashPendingNotice
    case profileAccountSectionTitle
    case profileAccountLoggedOutTitle
    case profileAccountLoggedOutSubtitle
    case profileAccountAppleLogin
    case profileAccountEmailLogin
    case profileAccountGoogleLogin
    case profileAccountInvite
    case profileAccountUpgrade
    case profileAccountActions
    case profileAccountSignOut
    case profileAccountDeleteAccount
    case profileAccountSignOutConfirmTitle
    case profileAccountSignOutConfirmMessage
    case profileAccountDeleteConfirmTitle
    case profileAccountDeleteConfirmMessage
    case profileAccountCancel
    case upgradeHeroTag
    case upgradeHeroTitle
    case upgradeFeaturePhotosTitle
    case upgradeFeaturePhotosSubtitle
    case upgradeFeatureVideosTitle
    case upgradeFeatureVideosSubtitle
    case upgradeFeatureAdfreeTitle
    case upgradeFeatureAdfreeSubtitle
    case upgradeFeatureOrganizeTitle
    case upgradeFeatureOrganizeSubtitle
    case upgradeFeatureStorageTitle
    case upgradeFeatureStorageSubtitle
    case upgradePlanYearlyTitle
    case upgradePlanYearlySubtitle
    case upgradePlanYearlyPrice
    case upgradePlanYearlyPeriod
    case upgradePlanLifetimeTitle
    case upgradePlanLifetimeSubtitle
    case upgradePlanLifetimePrice
    case upgradePlanLifetimePeriod
    case upgradePlanBestValue
    case upgradeCTAFreeTrial
    case upgradeCTALifetime
    case upgradeRestorePurchase
    case upgradeTermsOfService
    case upgradePrivacyPolicy
    case upgradeSubscriptionNote
    case upgradeProductsUnavailable
    case memberBasic
    case memberPremium
    case memberExpiryPrefix
    case memberLifetimeSuffix
    case memberNoExpiry
    case invitePlaceholder
    case inviteSubmit
    case inviteSuccessMessage
    case inviteInvalidMessage
    case inviteEmptyError
    case inviteLoginRequired
    case profileMoreSectionTitle
    case profileMoreHelp
    case profileMoreAbout
    case profileMoreAboutTitle
    case profileMoreAboutBody
    case profileLockedTitle
    case profileLockedMessage
    case subtitlePhotosScanning
    case subtitleVideosScanning
    case subtitlePermissionNeeded
    case subtitleSwipeHint
    case photoScanBackgroundTitle
    case photoScanPlaceholderTitle
    case photoScanPlaceholderMessage
    case photoEmptyTitle
    case photoEmptyMessage
    case actionRescan
    case actionContinue
    case actionLater
    case previewRequiresIOS17
    case actionDelete
    case actionCancel
    case actionDone
    case actionSelect
    case actionRestore
    case actionSelectAll
    case actionUnselectAll
    case actionMoveToTrash
    case actionGoToSettings
    case actionAdd
    case actionFavorite
    case actionShare
    case actionClearToRandom
    case actionSwitchToRandom
    case albumTabKept
    case albumTabCollections
    case albumTabTrash
    case albumDeleteConfirmationTitle
    case albumGridEmptyKept
    case albumGridEmptyTrash
    case albumSelectionPrompt
    case albumFolderHint
    case albumCollectionEmptyTitle
    case albumCollectionEmptyMessage
    case albumCategoryEmptyMessage
    case albumCollectionBackButton
    case favoriteComposerPrimaryTitle
    case favoriteComposerTitle
    case favoriteComposerPickerTitle
    case favoriteComposerNewSectionTitle
    case favoriteComposerNewButton
    case favoriteComposerConfirmNewButton
    case favoriteComposerNamePlaceholder
    case favoriteComposerAddButton
    case favoriteComposerCaptionTitle
    case favoriteComposerCaptionPlaceholder
    case favoriteComposerSaveButton
    case photoTutorialTitle
    case photoTutorialSubtitle
    case photoTutorialStepLeftTitle
    case photoTutorialStepLeftDescription
    case photoTutorialStepRightTitle
    case photoTutorialStepRightDescription
    case photoTutorialStepUpTitle
    case photoTutorialStepUpDescription
    case photoTutorialControlsHint
    case photoTutorialNext
    case photoTutorialStart
    case photoTutorialSkip
    case photoTutorialSettingsSectionTitle
    case photoTutorialReplayButton
    case videoSwipeHint
    case videoTutorialSwipeUp
    case videoTutorialSwipeDown
        case videoTutorialControlsTitle
        case videoTutorialFavoriteDetail
        case videoTutorialDeleteDetail
        case videoTutorialShareDetail
        case videoTutorialGotIt
        case videoTutorialEnableAudio
        case videoScanPlaceholderTitle
        case videoScanPlaceholderMessage
    case videoEmptyTitle
    case videoEmptyMessage
    case videoScanBackgroundTitle
    case photoGroupCompleteTitle
    case videoGroupCompleteTitle
    case videoTimeFilterEmptyTitle
    case videoTimeFilterEmptySubtitle
    case photoTimeFilterEmptyTitle
    case photoTimeFilterEmptySubtitle
    case groupDailyLimitReached
    case limitPhotoRemainingTitle
    case limitVideoRemainingTitle
    case limitExhaustedTitle
    case limitExhaustedSubtitlePhoto
    case limitExhaustedSubtitleVideo
    case limitPremiumSubtitle
    case limitGroupCleared
    case limitCTAReviewTrash
    case limitCTAUpgradePro
    case limitBenefitUnlimitedPhotos
    case limitBenefitUnlimitedVideos
    case limitBenefitEarlyAccess
    case mediaUnknownTimestamp
    case favoriteDefaultCategory
    case actionUpgrade
    case actionLogin
    case proRequiredTitle
    case proRequiredMessageTimeFilter
    case limitLoginHint
    case timeFilterNavigationTitle
    case timeFilterSectionTitle
    case timeFilterLoadingTitle
    case timeFilterLoadingMessage
    case timeFilterEmptyMessage
    case timeFilterEntryTitle
    case timeFilterAllTime
}

final class LanguagePreferences {
    static let shared = LanguagePreferences()

    private let lock = NSLock()
    private var storedLanguage: AppLanguage

    private init() {
        storedLanguage = AppLanguage.deviceDefault
    }

    var currentLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedLanguage
        }
        set {
            lock.lock()
            storedLanguage = newValue
            lock.unlock()
        }
    }
}

enum Localization {
    static func text(_ key: L10n, language: AppLanguage? = nil) -> String {
        let resolved = language ?? LanguagePreferences.shared.currentLanguage
        return AppLocalizer(language: resolved).text(key)
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue: AppLocalizer = AppLocalizer(language: .english)
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }

    var localizer: AppLocalizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}
