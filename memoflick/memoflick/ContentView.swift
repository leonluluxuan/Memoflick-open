//
//  ContentView.swift
//  memoflick
//
//  Created by leonlu on 2025/11/3.
//

import SwiftUI
import Photos
import UIKit

enum MainTab: Int {
    case photo
    case video
    case album
    case profile
}

enum PhotoSwipeHintDirection {
    case keep
    case delete
    case favorite
}

@available(iOS 17.0, *)
struct ContentView: View {
    @StateObject private var settingsStore: DeveloperSettingsStore
    @StateObject private var userSettingsStore: UserSettingsStore
    @StateObject private var photoWallSettingsStore: PhotoWallSettingsStore
    @StateObject private var viewModel: PhotoReviewViewModel
    @StateObject private var videoViewModel: VideoReviewViewModel
    @StateObject private var categoryStore: FavoriteCategoryStore
    @StateObject private var languageCoordinator: LanguageCoordinator
    @StateObject private var sizeStore = AssetSizeStore.shared
    @StateObject private var trashHistoryStore = TrashHistoryStore.shared
    @AppStorage("collection_sync_enabled") private var isSystemAlbumSyncEnabled = false

    @State private var currentTab: MainTab = .photo
    @State private var pendingSwipe: PhotoReviewViewModel.SwipeDirection?
    @State private var shouldMarkFavoriteForPendingSwipe = false
    @State private var activeSwipeDirection: PhotoSwipeHintDirection?
    @State private var undoAnimationDirection: PhotoReviewViewModel.SwipeDirection?
    @State private var sharePayload: SharePayload?
    @State private var favoriteComposerRequest: FavoriteComposerRequest?
    @State private var pendingFavoriteMetadata: FavoriteMetadata?
    @State private var showPhotoTutorial = false
    @State private var tutorialStepIndex = 0
    @State private var topPhotoCardFrame: CGRect?
    @State private var selectedAlbumTab: AlbumView.Tab = .kept
    @State private var isAlbumPreviewing: Bool = false
    @State private var isShowingAboutSheet: Bool = false
    @State private var isShowingPublicSettings: Bool = false
    @State private var shouldScrollToPhotoWall: Bool = false
    @State private var isPhotoWallRandomRefreshInFlight: Bool = false
#if DEV_PANEL
    @State private var isShowingDeveloperPanel: Bool = false
#endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme

    init() {
        let settingsStore = DeveloperSettingsStore()
        let userSettingsStore = UserSettingsStore()
        let photoWallSettingsStore = PhotoWallSettingsStore()
        let categoryStore = FavoriteCategoryStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _userSettingsStore = StateObject(wrappedValue: userSettingsStore)
        _photoWallSettingsStore = StateObject(wrappedValue: photoWallSettingsStore)
        _viewModel = StateObject(wrappedValue: PhotoReviewViewModel(settingsStore: settingsStore, userSettingsStore: userSettingsStore))
        _videoViewModel = StateObject(wrappedValue: VideoReviewViewModel(userSettingsStore: userSettingsStore))
        _categoryStore = StateObject(wrappedValue: categoryStore)
        _languageCoordinator = StateObject(wrappedValue: LanguageCoordinator())
    }

    var body: some View {
        GeometryReader { proxy in
            buildContent(safeAreaInsets: proxy.safeAreaInsets)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheetView(activityItems: [payload.image])
        }
        .sheet(isPresented: $isShowingPublicSettings) {
            CompactSettingsView(
                settings: $settingsStore.current,
                userSettings: $userSettingsStore.current,
                photoWallSettings: $photoWallSettingsStore.current,
                availableMonths: combinedAvailableMonths,
                isMonthListLoading: isMonthListLoading,
                scrollToPhotoWall: shouldScrollToPhotoWall,
                onScrollToPhotoWallHandled: { shouldScrollToPhotoWall = false },
                onReplayTutorial: {
                    userSettingsStore.current.hasSeenPhotoTutorial = false
                    restartPhotoTutorialFlow()
                },
                onSelectPhotoWallDaily: handlePhotoWallDailySelection,
                onSelectPhotoWallRandomOnce: handlePhotoWallRandomOnceSelection,
                onSelectPhotoWallManual: handlePhotoWallManualSelection
            ) {
                isShowingPublicSettings = false
            }
            .environment(\.appTheme, resolvedTheme)
            .environment(\.localizer, localizer)
            .environment(\.colorScheme, resolvedTheme.colorScheme)
            .id(resolvedTheme.colorScheme)
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingAboutSheet) {
            AboutSheetView()
                .environment(\.appTheme, resolvedTheme)
                .environment(\.localizer, localizer)
                .presentationDetents([.medium, .large])
        }
#if DEV_PANEL
        .sheet(isPresented: $isShowingDeveloperPanel) {
            DeveloperPanelView(
                settings: $settingsStore.current,
                onImportAssets: { identifiers, images in
                    if !identifiers.isEmpty {
                        viewModel.enqueueAssets(with: identifiers)
                    }
                    if !images.isEmpty {
                        viewModel.enqueueTestImages(images)
                    }
                },
                onForceLogout: {
                    forceLogoutFromDeveloperPanel()
                }
            )
            .presentationDetents([.medium, .large])
            .environment(\.appTheme, resolvedTheme)
            .environment(\.localizer, localizer)
        }
#endif
        .environment(\.appTheme, resolvedTheme)
        .environment(\.appLanguage, language)
        .environment(\.localizer, localizer)
        .environment(\.simulatedToday, simulatedToday)
        .preferredColorScheme(theme == .system ? nil : theme.colorScheme)
        .onAppear {
            LanguagePreferences.shared.currentLanguage = language
            syncPremiumBypassAndRefresh()
            handlePhotoWallAppBecameActive()
            warmTrashSizes()
        }
        .onChange(of: language) { newValue in
            LanguagePreferences.shared.currentLanguage = newValue
        }
#if DEV_PANEL
        .onChange(of: settingsStore.current.simulateLoggedIn) { _ in
            syncPremiumBypassAndRefresh()
        }
        .onChange(of: settingsStore.current.premiumOverride) { _ in
            syncPremiumBypassAndRefresh()
        }
#endif
        .onChange(of: viewModel.trashItems.map(\.id)) { _ in
            warmTrashSizes()
        }
        .onChange(of: videoViewModel.trashItems.map(\.id)) { _ in
            warmTrashSizes()
        }
        .onAppear {
            startPhotoTutorialFlowIfNeeded()
        }
        .onChange(of: viewModel.reviewDeck.count) { newCount in
            if newCount == 0 {
                showPhotoTutorial = false
            }
        }
    }
}

@available(iOS 17.0, *)
private extension ContentView {
    var combinedAvailableMonths: [YearMonth: Int] {
        var merged = viewModel.availableMonths
        for (key, value) in videoViewModel.availableMonths {
            merged[key, default: 0] += value
        }
        return merged
    }

    var isMonthListLoading: Bool {
        viewModel.isMonthListLoading || videoViewModel.isMonthListLoading
    }

    var theme: AppTheme {
        settingsStore.current.theme
    }

    var resolvedTheme: AppTheme {
        theme == .system ? (systemColorScheme == .dark ? .dark : .light) : theme
    }

    var language: AppLanguage {
        settingsStore.current.languageOverride ?? languageCoordinator.detectedLanguage
    }

    var localizer: AppLocalizer {
        AppLocalizer(language: language)
    }

    var simulatedToday: Date? {
#if DEV_PANEL
        settingsStore.current.simulatedDate
#else
        nil
#endif
    }

    var currentBackgroundColor: Color {
        currentTab == .video ? Color.black : resolvedTheme.contentBackground
    }

    var headerTitle: String {
        switch currentTab {
        case .photo, .video:
            return localizer.text(.headerTitlePhotos)
        case .album:
            return localizer.text(.headerTitleAlbum)
        case .profile:
            return localizer.text(.headerTitleProfile)
        }
    }

    var photoTutorialSteps: [PhotoTutorialStep] {
        [
            PhotoTutorialStep(
                title: localizer.text(.photoTutorialStepLeftTitle),
                description: localizer.text(.photoTutorialStepLeftDescription),
                direction: .left
            ),
            PhotoTutorialStep(
                title: localizer.text(.photoTutorialStepRightTitle),
                description: localizer.text(.photoTutorialStepRightDescription),
                direction: .right
            ),
            PhotoTutorialStep(
                title: localizer.text(.photoTutorialStepUpTitle),
                description: localizer.text(.photoTutorialStepUpDescription),
                direction: .up
            )
        ]
    }

    func syncPremiumBypassAndRefresh() {
        viewModel.updatePremiumBypass(true)
        videoViewModel.updatePremiumBypass(true)
        viewModel.refreshPhotoGroupStatus()
        videoViewModel.refreshGroupStatus()
    }

    func handlePhotoWallDailySelection() {
        photoWallSettingsStore.current.mode = .daily
        photoWallSettingsStore.current.manualAssetIdentifiers = []
        photoWallSettingsStore.current.pendingOneTimeRandom = false
        photoWallSettingsStore.current.lastDailyRefreshAt = Date()
        viewModel.requestPhotoWallRandomRefresh()
    }

    func handlePhotoWallRandomOnceSelection() {
        photoWallSettingsStore.current.mode = .daily
        photoWallSettingsStore.current.manualAssetIdentifiers = []
        triggerPhotoWallRandomOnceRefresh()
    }

    func handlePhotoWallManualSelection(_ identifiers: [String]) {
        photoWallSettingsStore.current.mode = .manual
        photoWallSettingsStore.current.manualAssetIdentifiers = identifiers
        photoWallSettingsStore.current.pendingOneTimeRandom = false
        viewModel.requestPhotoWallManualRefresh(identifiers: identifiers)
    }

    func handlePhotoWallAppBecameActive() {
        if WidgetPhotoStore.consumePendingOpenSettings() {
            shouldScrollToPhotoWall = true
            isShowingPublicSettings = true
        }
        refreshPhotoWallDailyIfNeeded()
    }

    func handlePhotoWallAppExited() {
        guard photoWallSettingsStore.current.pendingOneTimeRandom else { return }
        triggerPhotoWallRandomOnceRefresh()
    }

    func triggerPhotoWallRandomOnceRefresh() {
        guard !isPhotoWallRandomRefreshInFlight else { return }
        isPhotoWallRandomRefreshInFlight = true
        photoWallSettingsStore.current.pendingOneTimeRandom = true
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "photoWallRandomOnce") {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }

        Task {
            let success = await viewModel.performPhotoWallRandomRefresh()
            await MainActor.run {
                if success {
                    photoWallSettingsStore.current.pendingOneTimeRandom = false
                    photoWallSettingsStore.current.lastDailyRefreshAt = Date()
                }
                isPhotoWallRandomRefreshInFlight = false
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                    taskID = .invalid
                }
            }
        }
    }

    func refreshPhotoWallDailyIfNeeded() {
        guard photoWallSettingsStore.current.mode == .daily else { return }
        let now = Date()
        let lastRefresh = photoWallSettingsStore.current.lastDailyRefreshAt
        guard shouldRefreshPhotoWallDaily(lastRefresh, now: now) else { return }
        photoWallSettingsStore.current.lastDailyRefreshAt = now
        viewModel.requestPhotoWallRandomRefresh()
    }

    func shouldRefreshPhotoWallDaily(_ lastRefresh: Date?, now: Date) -> Bool {
        guard let lastRefresh else { return true }
        return !Calendar.current.isDate(lastRefresh, inSameDayAs: now)
    }

    func openHelpFeedback() {
        guard let url = URL(string: "https://github.com/leonluluxuan/Memoflick-open/issues") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func handleDevPanelLongPress() {
#if DEV_PANEL
        isShowingDeveloperPanel = true
#endif
    }

    func forceLogoutFromDeveloperPanel() {
#if DEV_PANEL
        settingsStore.current.simulateLoggedIn = false
#endif
    }

    @ViewBuilder
    func buildContent(safeAreaInsets: EdgeInsets) -> some View {
        let isShowingFavoriteComposer = favoriteComposerRequest != nil

        ZStack {
            ZStack {
                if currentTab == .video {
                    currentBackgroundColor
                        .ignoresSafeArea()
                } else {
                    currentBackgroundColor
                        .ignoresSafeArea() // 覆盖底部，避免默认白/黑条带露出
                }

                VStack(spacing: 0) {
                    if currentTab != .video && !(currentTab == .album && isAlbumPreviewing) {
                        header(safeAreaInsets: safeAreaInsets)
                    }

                    content(safeAreaInsets: safeAreaInsets)

                    if !(currentTab == .album && isAlbumPreviewing) {
                        tabBar(safeAreaInsets: safeAreaInsets)
                    }
                }
            }
            .blur(radius: isShowingFavoriteComposer ? 14 : 0)
            if let request = favoriteComposerRequest {
                FavoriteComposerView(
                    request: request,
                    categoryStore: categoryStore,
                    onCancel: { favoriteComposerRequest = nil },
                    onComplete: { metadata in
                        request.onSubmit(metadata)
                        favoriteComposerRequest = nil
                    }
                )
                .transition(.opacity)
            }
        }
#if DEV_PANEL
        .sheet(isPresented: $isShowingDeveloperPanel) {
            DeveloperPanelView(
                settings: $settingsStore.current,
                onImportAssets: { identifiers, images in
                    if !identifiers.isEmpty {
                        viewModel.enqueueAssets(with: identifiers)
                    }
                    if !images.isEmpty {
                        viewModel.enqueueTestImages(images)
                    }
                },
                onForceLogout: {
                    forceLogoutFromDeveloperPanel()
                }
            )
            .presentationDetents([.medium, .large])
            .environment(\.appTheme, resolvedTheme)
        }
#endif
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                viewModel.flushStore()
                videoViewModel.flushStore()
                viewModel.pauseScanning()
                videoViewModel.pauseScanning()
                handlePhotoWallAppExited()
            } else if phase == .active {
                viewModel.refreshPhotoGroupStatus()
                videoViewModel.refreshGroupStatus()
                viewModel.resumeScanningIfNeeded()
                Task { await videoViewModel.resumeScanningIfNeeded() }
                handlePhotoWallAppBecameActive()
            }
        }
        .onChange(of: viewModel.authorizationStatus) { status in
            if status == .authorized || status == .limited {
                startPhotoTutorialFlowIfNeeded()
            }
        }
        .onChange(of: currentTab) { tab in
            viewModel.flushStore()
            videoViewModel.flushStore()
            if tab == .video {
                Task { await videoViewModel.requestAccessIfNeeded() }
                Task { await videoViewModel.refreshIfNeeded() }
                showPhotoTutorial = false
            } else if tab == .photo {
                startPhotoTutorialFlowIfNeeded()
            }
        }
        .task {
            syncPremiumBypassAndRefresh()
            viewModel.requestAccessIfNeeded()
            async let languageTask: () = languageCoordinator.refreshLanguage()
            async let videoTask: () = videoViewModel.requestAccessIfNeeded()
            _ = await (languageTask, videoTask)
        }
        .onAppear {
            startPhotoTutorialFlowIfNeeded()
        }
        .onChange(of: viewModel.reviewDeck.count) { newCount in
            if newCount == 0 {
                if !viewModel.isInPhotoTutorial {
                    showPhotoTutorial = false
                }
            }
        }
        .onChange(of: favoriteComposerRequest?.id) { newValue in
            if newValue != nil {
                if !viewModel.isInPhotoTutorial {
                    showPhotoTutorial = false
                }
            }
        }
        .onChange(of: userSettingsStore.current.hasSeenPhotoTutorial) { seen in
            if !seen {
                startPhotoTutorialFlowIfNeeded()
            } else {
                showPhotoTutorial = false
            }
        }
        .animation(.easeInOut(duration: 0.2), value: favoriteComposerRequest?.id)
    }

    func header(safeAreaInsets: EdgeInsets) -> some View {
        HStack {
            Text(headerTitle)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(resolvedTheme == .dark ? Color.white : Color.black)
                .contentShape(Rectangle())
#if DEV_PANEL
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 5.0, maximumDistance: 80)
                        .onEnded { _ in
                            handleDevPanelLongPress()
                        }
                )
#endif

            Spacer()

            Button {
                isShowingPublicSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(resolvedTheme == .dark ? Color.white : Color.black)
                    .padding(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, safeAreaInsets.top > 0 ? 10 : 12)
        .background(
            resolvedTheme.contentBackground
                .ignoresSafeArea(edges: .top)
        )
    }

    @ViewBuilder
    func content(safeAreaInsets: EdgeInsets) -> some View {
        currentTabView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(currentBackgroundColor)
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch currentTab {
        case .photo:
            reviewView
        case .video:
            VideoModuleView(
                viewModel: videoViewModel,
                bottomPadding: 76,
                onFavoriteRequested: { presentVideoFavoriteComposer(for: $0) },
                onReviewDeleted: {
                    selectedAlbumTab = .trash
                    currentTab = .album
                }
            )
        case .album:
            AlbumView(
                keptItems: albumKeptItems,
                favoriteItems: albumFavoriteItems,
                trashItems: albumTrashItems,
                selectedTab: $selectedAlbumTab,
                isPreviewing: $isAlbumPreviewing,
                onRestore: handleAlbumRestore,
                onDeleteForever: handleAlbumDeleteForever,
                onMoveKeptToTrash: handleAlbumMoveToTrash,
                onFavorite: { presentAlbumFavoriteComposer(for: $0) },
                onReturnHome: { currentTab = .photo },
                categoryStore: categoryStore
            )
        case .profile:
            ProfileDashboardView(
                stats: profileStats,
                onShowTrash: {
                    selectedAlbumTab = .trash
                    currentTab = .album
                },
                onShowFavorites: {
                    selectedAlbumTab = .collections
                    currentTab = .album
                },
                onShowKept: {
                    selectedAlbumTab = .kept
                    currentTab = .album
                },
                onHelpFeedback: {
                    openHelpFeedback()
                },
                onAbout: {
                    isShowingAboutSheet = true
                }
            )
        }
    }

    var albumKeptItems: [AlbumMediaItem] {
        let photos = viewModel.keptItems
            .filter { !$0.id.hasPrefix("tutorial-") }
            .filter { !$0.meta.isFavorite }
            .map { AlbumMediaItem(photoItem: $0) }
        let videos = videoViewModel.keptItems
            .filter { !$0.meta.isFavorite }
            .map { AlbumMediaItem(videoItem: $0) }
        return (photos + videos).sorted { $0.updatedAt > $1.updatedAt }
    }

    var albumFavoriteItems: [AlbumMediaItem] {
        let photos = viewModel.keptItems
            .filter { !$0.id.hasPrefix("tutorial-") }
            .filter { $0.meta.isFavorite }
            .map { AlbumMediaItem(photoItem: $0) }
        let videos = videoViewModel.keptItems
            .filter { $0.meta.isFavorite }
            .map { AlbumMediaItem(videoItem: $0) }
        return (photos + videos).sorted { $0.updatedAt > $1.updatedAt }
    }

    var albumTrashItems: [AlbumMediaItem] {
        let photos = viewModel.trashItems
            .filter { !$0.id.hasPrefix("tutorial-") }
            .map { AlbumMediaItem(photoItem: $0) }
        let videos = videoViewModel.trashItems.map { AlbumMediaItem(videoItem: $0) }
        return (photos + videos).sorted { $0.updatedAt > $1.updatedAt }
    }

    var profileStats: ProfileStats {
        let historyBytes = trashHistoryStore.allRecords.reduce(Int64(0)) { $0 + $1.totalBytes }
        let photoClearedBytes = viewModel.trashItems
            .reduce(Int64(0)) { $0 + cachedBytes(for: $1) }
        let videoClearedBytes = videoViewModel.trashItems
            .reduce(Int64(0)) { $0 + cachedBytes(for: $1.asset) }
        let clearedCount = viewModel.trashItems.count + videoViewModel.trashItems.count
        let treasuredPhotos = viewModel.keptItems.filter { $0.meta.isFavorite }.count
        let treasuredVideos = videoViewModel.keptItems.filter { $0.meta.isFavorite }.count
        let organizedCount = viewModel.keptItems.count + videoViewModel.keptItems.count
        return ProfileStats(
            clearedBytes: historyBytes + photoClearedBytes + videoClearedBytes,
            clearedItems: clearedCount,
            treasuredCount: treasuredPhotos + treasuredVideos,
            organizedCount: organizedCount
        )
    }

    func handleAlbumRestore(_ items: [AlbumMediaItem]) {
        guard !items.isEmpty else { return }
        let trashItems = items.filter { $0.status == .trashed }
        let photoItems = trashItems.compactMap(\.photoItem)
        if !photoItems.isEmpty {
            viewModel.restoreFromTrash(items: photoItems)
        }
        let videoItems = trashItems.compactMap(\.videoItem)
        if !videoItems.isEmpty {
            videoViewModel.restoreFromTrash(items: videoItems)
        }
    }

    func handleAlbumDeleteForever(_ items: [AlbumMediaItem]) {
        guard !items.isEmpty else { return }
        let trashItems = items.filter { $0.status == .trashed }
        let photoItems = trashItems.compactMap(\.photoItem)
        if !photoItems.isEmpty {
            viewModel.deleteTrashItems(photoItems, simulatedDate: simulatedToday)
        }
        let videoItems = trashItems.compactMap(\.videoItem)
        if !videoItems.isEmpty {
            videoViewModel.deleteTrashItems(videoItems, simulatedDate: simulatedToday)
        }
        trashHistoryStore.record(items: trashItems, on: simulatedToday ?? Date())
    }

    func handleAlbumMoveToTrash(_ items: [AlbumMediaItem]) {
        guard !items.isEmpty else { return }
        let keptItems = items.filter { $0.status == .kept }
        let photoItems = keptItems.compactMap(\.photoItem)
        if !photoItems.isEmpty {
            viewModel.moveKeptItemsToTrash(photoItems, simulatedDate: simulatedToday)
        }
        let videoItems = keptItems.compactMap(\.videoItem)
        if !videoItems.isEmpty {
            videoViewModel.moveKeptItemsToTrash(videoItems, simulatedDate: simulatedToday)
        }
        trashHistoryStore.record(items: keptItems, on: simulatedToday ?? Date())
    }

    func cachedBytes(for photoItem: PhotoReviewItem) -> Int64 {
        if let testImage = photoItem.testImage {
            let pixelCount = testImage.pixelWidth * testImage.pixelHeight
            return Int64(pixelCount * 4)
        }
        if let asset = photoItem.asset,
           let cached = sizeStore.cachedSize(for: asset.localIdentifier) {
            return cached
        }
        return 0
    }

    func cachedBytes(for asset: PHAsset) -> Int64 {
        sizeStore.cachedSize(for: asset.localIdentifier) ?? 0
    }

    func warmTrashSizes() {
        let photoIDs = viewModel.trashItems.compactMap { $0.asset?.localIdentifier }
        let videoIDs = videoViewModel.trashItems.map { $0.asset.localIdentifier }
        let allIDs = photoIDs + videoIDs
        guard !allIDs.isEmpty else { return }
        for assetID in allIDs {
            sizeStore.requestSizeIfNeeded(for: assetID, allowNetworkAccess: true) { _ in }
        }
    }

    var reviewView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                let bottomInset = geometry.safeAreaInsets.bottom

                if isPhotoAccessDenied && !viewModel.hasAnyContent {
                    PermissionDeniedView(openSettingsAction: openSettings)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if viewModel.isScanning && !viewModel.hasPendingCards {
                    ScanningPlaceholder()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if !viewModel.hasPendingCards && viewModel.isUsingTimeFilter {
                    FilteredPhotosEmptyView(onResetRandom: {
                        viewModel.resetTimeFilterToAll()
                    })
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else if !viewModel.hasPendingCards {
                    NoMorePhotosView(onRefresh: {
                        Task { await viewModel.scanLibrary(force: true) }
                    })
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    ZStack(alignment: .bottom) {
                        PhotoCardStack(
                            items: viewModel.reviewDeck,
                            pendingSwipe: $pendingSwipe,
                            shouldMarkFavoriteForPendingSwipe: $shouldMarkFavoriteForPendingSwipe,
                            activeDirection: $activeSwipeDirection,
                            undoDirection: $undoAnimationDirection
                        ) { direction, markFavorite in
                            if viewModel.isInPhotoTutorial {
                                handleTutorialSwipe(direction)
                                return
                            }
                            let metadata = (direction == .keep && markFavorite)
                                ? (pendingFavoriteMetadata ?? FavoriteMetadata(caption: nil, categoryName: FavoriteCategoryStore.defaultCategoryName))
                                : nil
                            viewModel.swipeTopCard(direction, favoriteMetadata: metadata)
                            pendingFavoriteMetadata = nil
                        } onFavoriteSwipe: {
                            if viewModel.isInPhotoTutorial {
                                handleTutorialSwipe(.keep)
                            } else {
                                presentPhotoFavoriteComposer()
                            }
                        }
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: ControlButtonBar.totalHeight + bottomInset + 8, trailing: 16))
                        .onPreferenceChange(PhotoCardFramePreferenceKey.self) { frame in
                            topPhotoCardFrame = frame
                        }

                        ControlButtonBar(
                            canUndo: viewModel.canUndo,
                            isDeckEmpty: !viewModel.hasPendingCards,
                            highlightedDirection: activeSwipeDirection,
                            primaryFillColor: resolvedTheme.primaryControlFill,
                            secondaryFillColor: resolvedTheme.secondaryControlFill,
                            onUndo: {
                                shouldMarkFavoriteForPendingSwipe = false
                                if let record = viewModel.undoLastSwipe() {
                                    activeSwipeDirection = nil
                                    if record.previousStatus == .pending {
                                        undoAnimationDirection = record.swipeDirection
                                    }
                                }
                            },
                            onDelete: { triggerSwipe(.delete, markFavorite: false) },
                            onSave: { presentPhotoFavoriteComposer() },
                            onLike: { triggerSwipe(.keep, markFavorite: false) },
                            onForward: { shareTopPhoto() }
                        )
                        .padding(.horizontal, 20)
                        .padding(Edge.Set.bottom, bottomInset + 8)
                        .offset(y: -15) // 悬浮功能栏上移 15pt
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }

                if viewModel.isScanning && viewModel.hasPendingCards {
                    ScanProgressView(progress: viewModel.scanProgress)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                if showPhotoTutorial {
                    PhotoTutorialOverlay(
                        steps: photoTutorialSteps,
                        targetFrame: topPhotoCardFrame,
                        isVisible: $showPhotoTutorial,
                        onNext: advanceTutorialManually,
                        onSkip: skipPhotoTutorial,
                        currentIndex: tutorialStepIndex
                    )
                }
            }
        }
        .coordinateSpace(name: "photoReview")
    }

    @ViewBuilder
    func tabBar(safeAreaInsets: EdgeInsets) -> some View {
        let barHeight: CGFloat = 50
        FloatingTabBar(
            selectedTab: $currentTab,
            theme: resolvedTheme,
            localizer: localizer,
            safeAreaInsets: safeAreaInsets,
            customWidth: 280,
            barHeight: barHeight
        )
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            if currentTab == .video {
                Color.black
                    .frame(maxWidth: .infinity)
                    .frame(height: (barHeight + safeAreaInsets.bottom) * 1.4)
                    .offset(y: 60) // 下移额外 10pt
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
        }
    }

    var profilePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color(hex: "#6F86C9"))
            Text(localizer.text(.profileLockedTitle))
                .font(.headline)
            Text(localizer.text(.profileLockedMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    func startPhotoTutorialFlowIfNeeded(forceRestart: Bool = false) {
        guard currentTab == .photo else { return }
        guard !userSettingsStore.current.hasSeenPhotoTutorial else { return }
        guard favoriteComposerRequest == nil else { return }
        guard viewModel.authorizationStatus == .authorized || viewModel.authorizationStatus == .limited else { return }
        if viewModel.isInPhotoTutorial && !forceRestart {
            return
        }

        if forceRestart && viewModel.isInPhotoTutorial {
            viewModel.finishPhotoTutorial(restoreDeck: true)
            showPhotoTutorial = false
        }

        let tutorialItems = buildTutorialTestItems()
        tutorialStepIndex = 0
        viewModel.startPhotoTutorial(with: tutorialItems)
        withAnimation(.easeInOut(duration: 0.22)) {
            showPhotoTutorial = true
        }
    }

    func handleTutorialSwipe(_ direction: PhotoReviewViewModel.SwipeDirection) {
        guard viewModel.isInPhotoTutorial else { return }
        let expected = photoTutorialSteps[min(tutorialStepIndex, photoTutorialSteps.count - 1)].direction
        let isMatch: Bool
        switch expected {
        case .left:
            isMatch = direction == .delete
        case .right:
            isMatch = direction == .keep
        case .up:
            isMatch = direction == .keep // 上滑用 keep 逻辑，但这里只接受上滑
        }
        guard isMatch else {
            // 不匹配的方向不推进步骤
            return
        }
        viewModel.swipeTopCard(direction, favoriteMetadata: nil)
        tutorialStepIndex += 1
        if tutorialStepIndex >= photoTutorialSteps.count {
            endPhotoTutorialFlow()
        }
    }

    func advanceTutorialManually() {
        guard viewModel.isInPhotoTutorial else { return }
        if viewModel.hasPendingCards {
            viewModel.swipeTopCard(.keep, favoriteMetadata: nil)
        }
        tutorialStepIndex += 1
        if tutorialStepIndex >= photoTutorialSteps.count {
            endPhotoTutorialFlow()
        }
    }

    func skipPhotoTutorial() {
        endPhotoTutorialFlow()
    }

    func endPhotoTutorialFlow() {
        showPhotoTutorial = false
        viewModel.finishPhotoTutorial(restoreDeck: true)
        userSettingsStore.current.hasSeenPhotoTutorial = true
        Task {
            await viewModel.scanLibrary(force: true)
        }
    }

    func restartPhotoTutorialFlow() {
        startPhotoTutorialFlowIfNeeded(forceRestart: true)
    }

    var isPhotoAccessDenied: Bool {
        let status = viewModel.authorizationStatus
        return status == .denied || status == .restricted
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func triggerSwipe(_ direction: PhotoReviewViewModel.SwipeDirection, markFavorite: Bool) {
        guard pendingSwipe == nil, viewModel.hasPendingCards else { return }
        shouldMarkFavoriteForPendingSwipe = markFavorite
        pendingSwipe = direction
    }

    func buildTutorialTestItems() -> [PhotoReviewItem] {
        let now = Date()
        let leftText = localizer.text(.photoTutorialStepLeftTitle)
        let rightText = localizer.text(.photoTutorialStepRightTitle)
        let upText = localizer.text(.photoTutorialStepUpTitle)

        let leftImage = tutorialImage(
            color: UIColor(red: 0.36, green: 0.44, blue: 0.85, alpha: 1),
            text: leftText
        )
        let rightImage = tutorialImage(
            color: UIColor(red: 0.2, green: 0.7, blue: 0.6, alpha: 1),
            text: rightText
        )
        let upImage = tutorialImage(
            color: UIColor(red: 0.98, green: 0.76, blue: 0.26, alpha: 1),
            text: upText
        )

        let baseMetrics = PhotoMetrics(blurMetric: 0.2, averageBrightness: 0.6)
        let quality = PhotoQuality(blurScore: 0.5, exposureScore: 0.5, qualityScore: 0.5, tags: [])

        func makeItem(id: String, image: UIImage) -> PhotoReviewItem {
            let pixelWidth = Int(image.size.width * image.scale)
            let pixelHeight = Int(image.size.height * image.scale)
            let meta = PhotoMeta(
                id: id,
                metrics: baseMetrics,
                status: .pending,
                createdAt: now,
                updatedAt: now,
                isFavorite: false
            )
            let testImage = PhotoReviewItem.TestImage(
                image: image,
                creationDate: now,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight
            )
            return PhotoReviewItem(testImage: testImage, meta: meta, quality: quality)
        }

        return [
            makeItem(id: "tutorial-left", image: leftImage),
            makeItem(id: "tutorial-right", image: rightImage),
            makeItem(id: "tutorial-up", image: upImage)
        ]
    }

    func tutorialImage(color: UIColor, text: String) -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            color.setFill()
            context.fill(rect)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textRect = CGRect(x: 40, y: size.height / 2 - 60, width: size.width - 80, height: 120)
            attributed.draw(in: textRect)
        }
    }

    func shareTopPhoto() {
        guard viewModel.hasPendingCards, sharePayload == nil else { return }
        Task {
            if let image = await viewModel.shareImageForTopItem() {
                await MainActor.run {
                    sharePayload = SharePayload(image: image)
                }
            }
        }
    }

    func presentAlbumFavoriteComposer(for item: AlbumMediaItem) {
        let title: String
        if item.mediaType == .video, let duration = item.durationLabel {
            title = "\(item.displayDate) · \(duration)"
        } else {
            title = item.displayDate
        }

        let request = FavoriteComposerRequest(
            title: title,
            initialCaption: item.caption,
            initialCategory: item.categoryName
        ) { metadata in
            let sanitized = metadata.sanitized()
            if item.mediaType == .photo {
                viewModel.applyFavoriteMetadata(for: item.id, metadata: sanitized)
            } else {
                videoViewModel.applyFavoriteMetadata(for: item.id, metadata: sanitized)
            }
            syncFavoriteAssetToSystemAlbum(asset: item.asset, categoryName: sanitized.categoryName)
        }

        favoriteComposerRequest = request
    }

    func presentPhotoFavoriteComposer() {
        guard let item = viewModel.topReviewItem else { return }
        let targetID = item.id
        let request = FavoriteComposerRequest(
            title: item.displayDate,
            initialCaption: item.meta.caption,
            initialCategory: item.meta.categoryName
        ) { metadata in
            let sanitized = metadata.sanitized()
            guard viewModel.topReviewItem?.id == targetID else { return }
            pendingFavoriteMetadata = sanitized
            shouldMarkFavoriteForPendingSwipe = true
            triggerSwipe(.keep, markFavorite: true)
            syncFavoriteAssetToSystemAlbum(asset: item.asset, categoryName: sanitized.categoryName)
        }
        favoriteComposerRequest = request
    }

    func presentVideoFavoriteComposer(for item: VideoReviewItem) {
        let targetID = item.id
        let request = FavoriteComposerRequest(
            title: "\(item.displayDate) · \(item.durationLabel)",
            initialCaption: item.meta.caption,
            initialCategory: item.meta.categoryName
        ) { metadata in
            let sanitized = metadata.sanitized()
            guard let current = videoViewModel.currentVideo, current.id == targetID else { return }
            videoViewModel.keepCurrent(favoriteMetadata: sanitized)
            syncFavoriteAssetToSystemAlbum(asset: current.asset, categoryName: sanitized.categoryName)
        }
        favoriteComposerRequest = request
    }

    private func syncFavoriteAssetToSystemAlbum(asset: PHAsset?, categoryName: String?) {
        guard isSystemAlbumSyncEnabled else { return }
        guard let asset else { return }
        let trimmed = categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        addAssetToSystemAlbum(asset: asset, albumName: trimmed)
    }

    private func addAssetToSystemAlbum(asset: PHAsset, albumName: String) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localizedTitle = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )

        if let collection = collections.firstObject {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest(for: collection)
                request?.addAssets([asset] as NSArray)
            }, completionHandler: nil)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            request.addAssets([asset] as NSArray)
        }, completionHandler: nil)
    }
}

private struct ControlButtonBar: View {
    var canUndo: Bool
    var isDeckEmpty: Bool
    var highlightedDirection: PhotoSwipeHintDirection?
    var primaryFillColor: Color
    var secondaryFillColor: Color
    var onUndo: () -> Void
    var onDelete: () -> Void
    var onSave: () -> Void
    var onLike: () -> Void
    var onForward: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            SecondaryCircleButton(
                icon: "arrow.uturn.backward",
                size: 50,
                background: secondaryFillColor,
                foreground: Color(hex: "#f7b731"),
                isEnabled: canUndo,
                action: onUndo
            )
            .opacity(highlightedDirection == nil ? 1 : 0)
            .allowsHitTesting(highlightedDirection == nil)

            PrimaryCircleButton(
                icon: "xmark",
                size: 66,
                fillColor: primaryFillColor,
                strokeColor: Color(hex: "#6F86C9"),
                iconColor: Color(hex: "#6F86C9"),
                isEnabled: !isDeckEmpty,
                action: onDelete
            )
            .opacity(highlightedDirection == nil || highlightedDirection == .delete ? 1 : 0)
            .allowsHitTesting((highlightedDirection == nil || highlightedDirection == .delete) && !isDeckEmpty)

            SecondaryCircleButton(
                icon: "star.fill",
                size: 50,
                background: secondaryFillColor,
                foreground: Color(hex: "#3498db"),
                isEnabled: !isDeckEmpty,
                action: onSave
            )
            .opacity(highlightedDirection == nil || highlightedDirection == .favorite ? 1 : 0)
            .allowsHitTesting((highlightedDirection == nil || highlightedDirection == .favorite) && !isDeckEmpty)

            PrimaryCircleButton(
                icon: "checkmark",
                size: 66,
                fillColor: primaryFillColor,
                strokeColor: Color(hex: "#00F0A9"),
                iconColor: Color(hex: "#00F0A9"),
                isEnabled: !isDeckEmpty,
                action: onLike
            )
            .opacity(highlightedDirection == nil || highlightedDirection == .keep ? 1 : 0)
            .allowsHitTesting((highlightedDirection == nil || highlightedDirection == .keep) && !isDeckEmpty)

            SecondaryCircleButton(
                icon: "arrowshape.turn.up.right.fill",
                size: 50,
                background: secondaryFillColor,
                foreground: Color(hex: "#2980b9"),
                isEnabled: !isDeckEmpty,
                action: onForward
            )
            .opacity(highlightedDirection == nil ? 1 : 0)
            .allowsHitTesting(highlightedDirection == nil && !isDeckEmpty)
        }
        .animation(.easeInOut(duration: 0.12), value: highlightedDirection)
    }

    static let totalHeight: CGFloat = 96
}

private struct PrimaryCircleButton: View {
    let icon: String
    let size: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let iconColor: Color
    var showsStroke: Bool = true
    var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fillColor)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 10)
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: 3)
                        .opacity(showsStroke ? 1 : 0)
                        .padding(5)
                )
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(iconColor)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .buttonStyle(.plain)
    }
}

private struct SecondaryCircleButton: View {
    let icon: String
    let size: CGFloat
    let background: Color
    let foreground: Color
    var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(background)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.1), radius: 9, x: 0, y: 6)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.32, weight: .bold))
                        .foregroundStyle(foreground)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .buttonStyle(.plain)
    }
}

private struct ScanProgressView: View {
    var progress: Double
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localizer.text(.photoScanBackgroundTitle))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(Color(hex: "#6F86C9"))
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ScanningPlaceholder: View {
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(localizer.text(.photoScanPlaceholderTitle))
                .font(.headline)
            Text(localizer.text(.photoScanPlaceholderMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NoMorePhotosView: View {
    var onRefresh: () -> Void
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#00F0A9"))
            Text(localizer.text(.photoEmptyTitle))
                .font(.headline)
            Text(localizer.text(.photoEmptyMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button(localizer.text(.actionRescan)) {
                onRefresh()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct FilteredPhotosEmptyView: View {
    var onResetRandom: () -> Void
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(localizer.text(.photoTimeFilterEmptyTitle))
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Text(localizer.text(.photoTimeFilterEmptySubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button(localizer.text(.actionSwitchToRandom)) {
                onResetRandom()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}


#Preview {
    if #available(iOS 17.0, *) {
        ContentView()
    } else {
        Text(Localization.text(.previewRequiresIOS17))
    }
}
