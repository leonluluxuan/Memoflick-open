//
//  PhotoReviewViewModel.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import Foundation
import Combine
import Photos
import UIKit
import ImageIO

@MainActor
final class PhotoReviewViewModel: ObservableObject {
    fileprivate struct ScanBatchResult: Sendable {
        var pending: [PhotoReviewItem]
        var kept: [PhotoReviewItem]
        var trashed: [PhotoReviewItem]

        static let empty = ScanBatchResult(pending: [], kept: [], trashed: [])
    }

    fileprivate struct ScanTaskOutput: Sendable {
        var result: ScanBatchResult
        var processedIdentifiers: Set<String>
    }

    enum SwipeDirection {
        case keep
        case delete
    }

    struct SwipeRecord {
        var item: PhotoReviewItem
        var previousStatus: PhotoProcessStatus
        var previousIsFavorite: Bool
        var previousCaption: String?
        var previousCategoryName: String?
        var swipeDirection: SwipeDirection
    }

    @Published private(set) var authorizationStatus: PHAuthorizationStatus
    @Published private(set) var reviewDeck: [PhotoReviewItem] = []
    @Published private(set) var keptItems: [PhotoReviewItem] = []
    @Published private(set) var trashItems: [PhotoReviewItem] = []
    @Published private(set) var photoGroupStatus: GroupUsageSnapshot
    @Published private(set) var currentGroupClearedBytes: Int64 = 0
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var isPremiumBypass = true
    @Published var premiumGroupCompleted: Bool = false
    @Published private(set) var availableMonths: [YearMonth: Int] = [:]
    @Published var isMonthListLoading = false
    @Published var isInPhotoTutorial = false

    private let libraryManager = PhotoLibraryManager()
    private let analyzer = PhotoAnalyzer()
    private let metaStore = PhotoMetaStore()
    private let sizeStore: AssetSizeStore
    private let settingsStore: DeveloperSettingsStore
    private let userSettingsStore: UserSettingsStore
    private let photoGroupTracker: ReviewGroupTracker
    private var allAssets: [PHAsset] = []
    private var randomizedAssets: [PHAsset] = []
    private var filteredAssets: [PHAsset] = []
    private var testItems: [String: PhotoReviewItem] = [:]
    private var history: [SwipeRecord] = []
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedCachedState = false
    private var lastQualitySignature: Int?
    private var lastTimeFilterSignature: Int?
    private var processedAssetIDs = Set<String>()
    private var initialScanTask: Task<Void, Never>?
    private var backgroundScanTask: Task<Void, Never>?
    private var monthAggregationTask: Task<Void, Never>?
    private var currentTimeFilter: MediaTimeFilter
    private var tutorialBackupDeck: [PhotoReviewItem] = []
    private var bufferedScanResult: ScanBatchResult = .empty
    private var clearedSizeByItemID: [String: Int64] = [:]
    private var pendingClearedSizeIDs: Set<String> = []
    private let initialScanSampleSize = 180
    private let initialChunkSize = 40
    private let backgroundChunkSize = 60
    private let widgetSnapshotExportLimit = 32
    private let widgetManualExportLimit = 16
    private let widgetRandomSampleMultiplier = 4
    private let widgetThumbnailSize = CGSize(width: 320, height: 320)
    private let widgetThumbnailQuality: CGFloat = 0.75
    private var widgetSyncTask: Task<Void, Never>?
    private let networkMonitor = NetworkMonitor.shared
    private let randomSeed = PhotoReviewViewModel.loadRandomSeed(key: "photo_random_seed")
    private let photoGroupConfig = ReviewGroupTracker.Config(
        groupSize: 15,
        dailyLimit: 3,
        storageKey: "photo-review-group"
    )

    init(
        settingsStore: DeveloperSettingsStore,
        userSettingsStore: UserSettingsStore,
        sizeStore: AssetSizeStore? = nil
    ) {
        self.settingsStore = settingsStore
        self.userSettingsStore = userSettingsStore
        self.sizeStore = sizeStore ?? AssetSizeStore.shared
        let tracker = ReviewGroupTracker(config: photoGroupConfig)
        photoGroupTracker = tracker
        photoGroupStatus = tracker.currentStatus()
        authorizationStatus = libraryManager.currentAuthorizationStatus()
        currentTimeFilter = userSettingsStore.current.photoTimeFilter

        settingsStore.$current
            .sink { [weak self] newSettings in
                Task { await self?.apply(settings: newSettings) }
            }
            .store(in: &cancellables)

        userSettingsStore.$current
            .map { $0.photoTimeFilter }
            .removeDuplicates { lhs, rhs in
                Self.timeFilterSignature(lhs) == Self.timeFilterSignature(rhs)
            }
            .sink { [weak self] newFilter in
                Task { await self?.apply(timeFilter: newFilter) }
            }
            .store(in: &cancellables)

        Task { await bootstrapIfNeeded() }
    }

    deinit {
        initialScanTask?.cancel()
        backgroundScanTask?.cancel()
        monthAggregationTask?.cancel()
        widgetSyncTask?.cancel()
    }

    var developerSettings: DeveloperSettings {
        settingsStore.current
    }

    var canUndo: Bool {
        !history.isEmpty
    }

    var hasPendingCards: Bool {
        !reviewDeck.isEmpty
    }

    var hasAnyContent: Bool {
        hasPendingCards || !keptItems.isEmpty || !trashItems.isEmpty
    }
    var isUsingTimeFilter: Bool {
        if case .all = currentTimeFilter { return false }
        return true
    }

    var topReviewItem: PhotoReviewItem? {
        reviewDeck.first
    }

    func refreshPhotoGroupStatus() {
        photoGroupStatus = adjustedSnapshot(photoGroupTracker.currentStatus())
    }

    func startPhotoTutorial(with tutorialItems: [PhotoReviewItem]) {
        guard !isInPhotoTutorial else { return }
        tutorialBackupDeck = reviewDeck
        reviewDeck = tutorialItems
        isInPhotoTutorial = true
        bufferedScanResult = .empty
    }

    func finishPhotoTutorial(restoreDeck: Bool) {
        isInPhotoTutorial = false
        if restoreDeck {
            reviewDeck = arrangedDeck(from: tutorialBackupDeck)
        }
        tutorialBackupDeck = []
        applyBufferedScanResult(restoreDeck: restoreDeck)
        resumeScanningIfNeeded()
    }

    func pauseScanning() {
        initialScanTask?.cancel()
        backgroundScanTask?.cancel()
        initialScanTask = nil
        backgroundScanTask = nil
        isScanning = false
    }

    func resumeScanningIfNeeded() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        guard !isScanning else { return }
        let remaining = unprocessedAssets()
        guard !remaining.isEmpty else { return }
        guard !isInPhotoTutorial else { return }

        let allowNetworkAccess = networkMonitor.allowsICloudDownload
        let worker = PhotoScanWorker(analyzer: analyzer, metaStore: metaStore, allowNetworkAccess: allowNetworkAccess)
        startBackgroundScan(with: worker, assets: remaining)
    }

    func startNextPhotoGroupIfAvailable() {
        let snapshot = isPremiumBypass
            ? photoGroupTracker.startNextGroupIgnoringLimit()
            : photoGroupTracker.startNextGroupIfAvailable()
        photoGroupStatus = adjustedSnapshot(snapshot)
        currentGroupClearedBytes = 0
        clearedSizeByItemID.removeAll()
        pendingClearedSizeIDs.removeAll()
    }

    func resetTimeFilterToAll() {
        userSettingsStore.current.photoTimeFilter = .all
        userSettingsStore.current.videoTimeFilter = .all
    }

    func requestAccessIfNeeded() {
        Task {
            let status = authorizationStatus
            if status == .notDetermined || status == .limited {
                let newStatus = await libraryManager.requestAuthorization()
                await MainActor.run {
                    self.authorizationStatus = newStatus
                }
                await bootstrapIfNeeded()
            } else if status == .authorized || status == .limited {
                await bootstrapIfNeeded()
            }
        }
    }

    func scanLibrary(force: Bool = false) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        if isScanning { return }
        await metaStore.waitUntilLoaded()
        refreshPhotoGroupStatus()

        initialScanTask?.cancel()
        backgroundScanTask?.cancel()
        initialScanTask = nil
        backgroundScanTask = nil
        if force {
            processedAssetIDs.removeAll()
        }
        isScanning = true
        scanProgress = 0

        let fullAssets = await libraryManager.fetchPhotoAssetsAsync(limit: nil, sortAscending: false)
        mergeLibraryAssets(fullAssets, replaceExisting: true)
        refreshAvailableMonths(with: fullAssets)
        randomizedAssets = stableRandomizedAssets(from: allAssets)
        filteredAssets = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)

        if force || processedAssetIDs.isEmpty {
            let cachedMeta = await metaStore.allMeta()
            processedAssetIDs = Set(cachedMeta.map(\.id))
            if !hasLoadedCachedState {
                await rebuildDeckFromCache(
                    cachedMeta: cachedMeta,
                    filteredAssets: filteredAssets
                )
            }
        }

        let remaining = unprocessedAssets()
        guard !remaining.isEmpty else {
            scanProgress = 1
            isScanning = false
            return
        }

        let allowNetworkAccess = networkMonitor.allowsICloudDownload
        let worker = PhotoScanWorker(analyzer: analyzer, metaStore: metaStore, allowNetworkAccess: allowNetworkAccess)
        let initialAssets = prioritizedInitialAssets(from: remaining, limit: initialScanSampleSize)
        let totalAssetCount = max(allAssets.count, 1)
        let initialChunks = chunkAssets(initialAssets, chunkSize: adaptiveChunkSize(initialChunkSize))
        initialScanTask = Task(priority: .userInitiated) { [weak self] in
            await self?.runInitialScan(
                chunks: initialChunks,
                totalAssetCount: totalAssetCount,
                worker: worker
            )
        }
    }

    nonisolated private func runInitialScan(
        chunks: [[PHAsset]],
        totalAssetCount: Int,
        worker: PhotoScanWorker
    ) async {
        defer {
            Task { @MainActor in
                self.initialScanTask = nil
            }
        }

        var hasInjectedInitialResults = false
        var localProcessedIDs = await MainActor.run { self.processedAssetIDs }

        for chunk in chunks {
            if Task.isCancelled { break }
            let chunkToProcess = chunk.filter { !localProcessedIDs.contains($0.localIdentifier) }
            if chunkToProcess.isEmpty {
                continue
            }

            let output = await worker.processAssets(chunkToProcess, startingProcessedIDs: localProcessedIDs)
            localProcessedIDs = output.processedIdentifiers
            let progress = min(1, Double(localProcessedIDs.count) / Double(max(totalAssetCount, 1)))
            let result = output.result
            let inserted = !(result.pending.isEmpty && result.kept.isEmpty && result.trashed.isEmpty)
            let processedIDsSnapshot = localProcessedIDs
            let replaceExisting = !hasInjectedInitialResults && !result.pending.isEmpty
            await MainActor.run {
                self.processedAssetIDs = processedIDsSnapshot
                self.applyScanResult(result, replaceExisting: replaceExisting)
                self.scanProgress = progress
                self.hasLoadedCachedState = true
            }

            if inserted {
                hasInjectedInitialResults = true
            }

            if Task.isCancelled { break }
        }

        await MainActor.run {
            let totalCount = max(self.allAssets.count, 1)
            if self.processedAssetIDs.count >= totalCount {
                self.scanProgress = 1
            }
            let remaining = self.unprocessedAssets()
            if !remaining.isEmpty {
                let allowNetworkAccess = self.networkMonitor.allowsICloudDownload
                let networkWorker = PhotoScanWorker(analyzer: self.analyzer, metaStore: self.metaStore, allowNetworkAccess: allowNetworkAccess)
                self.startBackgroundScan(with: networkWorker, assets: remaining)
            } else {
                self.isScanning = false
            }
        }
    }

    @MainActor
    private func startBackgroundScan(with worker: PhotoScanWorker, assets: [PHAsset]) {
        backgroundScanTask?.cancel()
        let chunks = chunkAssets(assets, chunkSize: adaptiveChunkSize(backgroundChunkSize))
        isScanning = true
        backgroundScanTask = Task(priority: .background) { [weak self] in
            await self?.runBackgroundScan(chunks: chunks, worker: worker)
        }
    }

    nonisolated private func runBackgroundScan(chunks: [[PHAsset]], worker: PhotoScanWorker) async {
        defer {
            Task { @MainActor in
                self.backgroundScanTask = nil
                self.isScanning = false
            }
        }

        var localProcessedIDs = await MainActor.run { self.processedAssetIDs }

        for chunk in chunks {
            if Task.isCancelled { break }
            let chunkToProcess = chunk.filter { !localProcessedIDs.contains($0.localIdentifier) }
            if chunkToProcess.isEmpty { continue }

            let output = await worker.processAssets(chunkToProcess, startingProcessedIDs: localProcessedIDs)
            localProcessedIDs = output.processedIdentifiers
            let result = output.result
            if result.pending.isEmpty && result.kept.isEmpty && result.trashed.isEmpty {
                continue
            }

            let processedIDsSnapshot = localProcessedIDs
            await MainActor.run {
                self.processedAssetIDs = processedIDsSnapshot
                self.applyScanResult(result, replaceExisting: false)
                let totalCount = max(self.allAssets.count, 1)
                self.scanProgress = min(1, Double(processedIDsSnapshot.count) / Double(totalCount))
            }
        }
    }

    func swipeTopCard(
        _ direction: SwipeDirection,
        favoriteMetadata: FavoriteMetadata? = nil
    ) {
        guard !reviewDeck.isEmpty else { return }
        if photoGroupStatus.isGateActive && !isPremiumBypass && !isInPhotoTutorial {
            return
        }
        var item = reviewDeck.removeFirst()
        let previousStatus = item.meta.status
        let previousFavorite = item.meta.isFavorite
        let previousCaption = item.meta.caption
        let previousCategory = item.meta.categoryName
        let newStatus: PhotoProcessStatus = (direction == .keep) ? .kept : .trashed

        if direction == .keep, let favoriteMetadata {
            let sanitized = favoriteMetadata.sanitized()
            item.meta.isFavorite = true
            item.meta.caption = sanitized.caption
            item.meta.categoryName = sanitized.categoryName
        } else {
            item.meta.isFavorite = false
            item.meta.caption = nil
            item.meta.categoryName = nil
        }
        item.meta.status = newStatus
        item.meta.updatedAt = Date()
        history.append(
            SwipeRecord(
                item: item,
                previousStatus: previousStatus,
                previousIsFavorite: previousFavorite,
                previousCaption: previousCaption,
                previousCategoryName: previousCategory,
                swipeDirection: direction
            )
        )

        if item.isTestItem {
            testItems[item.id] = item
        } else {
            Task {
                await metaStore.upsert(item.meta)
                await metaStore.flush()
            }
        }

        if newStatus == .kept {
            keptItems.insert(item, at: 0)
        } else {
            trashItems.insert(item, at: 0)
            trackClearedBytes(for: item)
        }
        let snapshot = photoGroupTracker.registerConsumption()
        handleGroupCompletionIfNeeded(rawSnapshot: snapshot)
        photoGroupStatus = adjustedSnapshot(snapshot)
        syncWidgetStore()
    }

    func shareImageForTopItem() async -> UIImage? {
        guard let item = topReviewItem else { return nil }
        return await loadImage(for: item)
    }

    func applyFavoriteMetadata(for id: String, metadata: FavoriteMetadata) {
        let sanitized = metadata.sanitized()
        if let index = keptItems.firstIndex(where: { $0.id == id }) {
            var item = keptItems.remove(at: index)
            item.meta.isFavorite = true
            item.meta.caption = sanitized.caption
            item.meta.categoryName = sanitized.categoryName
            item.meta.updatedAt = Date()
            keptItems.insert(item, at: 0)
            Task {
                await metaStore.upsert(item.meta)
                await metaStore.flush()
            }
            syncWidgetStore()
            return
        }

        if let index = trashItems.firstIndex(where: { $0.id == id }) {
            var item = trashItems.remove(at: index)
            item.meta.isFavorite = true
            item.meta.caption = sanitized.caption
            item.meta.categoryName = sanitized.categoryName
            item.meta.updatedAt = Date()
            trashItems.insert(item, at: 0)
            Task {
                await metaStore.upsert(item.meta)
                await metaStore.flush()
            }
            syncWidgetStore()
        }
    }

    @discardableResult
    func undoLastSwipe() -> SwipeRecord? {
        guard let record = history.popLast() else { return nil }
        var restoredMeta = record.item.meta
        restoredMeta.status = record.previousStatus
        restoredMeta.updatedAt = Date()
        restoredMeta.isFavorite = record.previousIsFavorite
        restoredMeta.caption = record.previousCaption
        restoredMeta.categoryName = record.previousCategoryName

        if record.item.meta.status == .kept {
            keptItems.removeAll { $0.id == record.item.id }
        } else if record.item.meta.status == .trashed {
            trashItems.removeAll { $0.id == record.item.id }
            if record.previousStatus != .trashed {
                removeClearedBytes(for: record.item)
            }
        }
        if record.previousStatus == .pending {
            let snapshot = photoGroupTracker.undoConsumption()
            photoGroupStatus = adjustedSnapshot(snapshot)
        }

        if record.item.isTestItem {
            guard var cached = testItems[record.item.id] else { return record }
            cached.meta = restoredMeta
            cached.quality = analyzer.quality(for: restoredMeta.metrics)
            testItems[record.item.id] = cached

            switch restoredMeta.status {
            case .pending:
                insertIntoDeck(cached, preferFront: true)
            case .kept:
                keptItems.insert(cached, at: 0)
            case .trashed:
                trashItems.insert(cached, at: 0)
            }
            syncWidgetStore()
            return record
        }

        Task {
            await metaStore.upsert(restoredMeta)
            await metaStore.flush()
        }

        if restoredMeta.status == .pending,
           let asset = allAssets.first(where: { $0.localIdentifier == restoredMeta.id }) {
            let quality = analyzer.quality(for: restoredMeta.metrics)
            let restoredItem = PhotoReviewItem(asset: asset, meta: restoredMeta, quality: quality)
            insertIntoDeck(restoredItem, preferFront: true)
        }
        syncWidgetStore()
        return record
    }

    func recalculateBasedOnSettings() {
        Task {
            await apply(settings: settingsStore.current, force: true)
        }
    }

    func enqueueAssets(with identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        Task {
            guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var newPending: [PhotoReviewItem] = []
            var newKept: [PhotoReviewItem] = []
            var newTrash: [PhotoReviewItem] = []

            for index in 0..<fetchResult.count {
                let asset = fetchResult.object(at: index)
                var meta = await metaStore.meta(for: asset.localIdentifier)

                if meta == nil {
                    if let metrics = await analyzer.analyze(asset: asset, allowNetworkAccess: true) {
                        let now = Date()
                        let newMeta = PhotoMeta(
                            id: asset.localIdentifier,
                            metrics: metrics,
                            status: .pending,
                            createdAt: now,
                            updatedAt: now,
                            isFavorite: false
                        )
                        await metaStore.upsert(newMeta)
                        meta = newMeta
                    }
                }

                guard let resolvedMeta = meta else { continue }
                let quality = analyzer.quality(for: resolvedMeta.metrics)
                let item = PhotoReviewItem(asset: asset, meta: resolvedMeta, quality: quality)

                switch resolvedMeta.status {
                case .pending:
                    newPending.append(item)
                case .kept:
                    newKept.append(item)
                case .trashed:
                    newTrash.append(item)
                }

                if !allAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                    allAssets.append(asset)
                }
            }

            await metaStore.flush()

            await MainActor.run {
                for item in newPending {
                    reviewDeck.removeAll { $0.id == item.id }
                    insertIntoDeck(item)
                }
                for item in newKept {
                    keptItems.removeAll { $0.id == item.id }
                    keptItems.insert(item, at: 0)
                }
                for item in newTrash {
                    trashItems.removeAll { $0.id == item.id }
                    trashItems.insert(item, at: 0)
                }
            }
        }
    }

    func enqueueTestImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }

        for image in images {
            guard let metrics = analyzer.analyze(image: image) else { continue }
            let now = Date()
            let identifier = "test-\(UUID().uuidString)"
            let meta = PhotoMeta(
                id: identifier,
                metrics: metrics,
                status: .pending,
                createdAt: now,
                updatedAt: now,
                isFavorite: false
            )
            let quality = analyzer.quality(for: metrics)
            let pixelWidth = Int(image.size.width * image.scale)
            let pixelHeight = Int(image.size.height * image.scale)
            let testImage = PhotoReviewItem.TestImage(
                image: image,
                creationDate: now,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight
            )
            let item = PhotoReviewItem(testImage: testImage, meta: meta, quality: quality)
            testItems[item.id] = item
            insertIntoDeck(item)
        }
    }

    func restoreFromTrash(_ item: PhotoReviewItem) {
        trashItems.removeAll { $0.id == item.id }
        var restoredMeta = item.meta
        restoredMeta.status = .pending
        restoredMeta.updatedAt = Date()
        restoredMeta.isFavorite = false
        restoredMeta.caption = nil
        restoredMeta.categoryName = nil

        if item.isTestItem {
            guard var cached = testItems[item.id] else { return }
            cached.meta = restoredMeta
            cached.quality = analyzer.quality(for: restoredMeta.metrics)
            testItems[item.id] = cached
            insertIntoDeck(cached)
        } else {
            Task {
                await metaStore.upsert(restoredMeta)
                await metaStore.flush()
            }

            if let asset = allAssets.first(where: { $0.localIdentifier == restoredMeta.id }) {
                let quality = analyzer.quality(for: restoredMeta.metrics)
                let restoredItem = PhotoReviewItem(asset: asset, meta: restoredMeta, quality: quality)
                insertIntoDeck(restoredItem)
            }
        }
        syncWidgetStore()
    }

    func restoreFromTrash(items: [PhotoReviewItem]) {
        guard !items.isEmpty else { return }
        for item in items {
            restoreFromTrash(item)
        }
    }

    func updatePremiumBypass(_ isPremium: Bool) {
        isPremiumBypass = isPremium
        if !isPremium {
            premiumGroupCompleted = false
        }
        photoGroupStatus = adjustedSnapshot(photoGroupStatus)
    }

    private func trackClearedBytes(for item: PhotoReviewItem) {
        if let testImage = item.testImage {
            let size = testImageBytes(testImage)
            clearedSizeByItemID[item.id] = size
            currentGroupClearedBytes += size
            return
        }
        guard let asset = item.asset else { return }
        let itemID = item.id
        let assetID = asset.localIdentifier
        if let cached = sizeStore.cachedSize(for: assetID) {
            clearedSizeByItemID[itemID] = cached
            currentGroupClearedBytes += cached
            return
        }

        pendingClearedSizeIDs.insert(itemID)
        Task {
            let size = await sizeStore.requestSize(for: assetID, allowNetworkAccess: true)
            await MainActor.run {
                guard self.pendingClearedSizeIDs.contains(itemID) else { return }
                self.pendingClearedSizeIDs.remove(itemID)
                guard let size else { return }
                self.clearedSizeByItemID[itemID] = size
                self.currentGroupClearedBytes += size
            }
        }
    }

    private func removeClearedBytes(for item: PhotoReviewItem) {
        pendingClearedSizeIDs.remove(item.id)
        if let size = clearedSizeByItemID.removeValue(forKey: item.id) {
            currentGroupClearedBytes = max(0, currentGroupClearedBytes - size)
        }
    }

    private func testImageBytes(_ testImage: PhotoReviewItem.TestImage) -> Int64 {
        let pixelCount = testImage.pixelWidth * testImage.pixelHeight
        return Int64(pixelCount * 4)
    }

    private func filterAssets(_ assets: [PHAsset], using filter: MediaTimeFilter) -> [PHAsset] {
        switch filter {
        case .all:
            return assets
        case let .months(months):
            guard !months.isEmpty else { return assets }
            let bucket = Set(months)
            return assets.filter { asset in
                guard let date = asset.creationDate, let ym = YearMonth(date: date) else { return false }
                return bucket.contains(ym)
            }
        }
    }

    private func filteredRandomAssets(from assets: [PHAsset], using filter: MediaTimeFilter) -> [PHAsset] {
        let filtered = filterAssets(assets, using: filter)
        return stableRandomizedAssets(from: filtered)
    }

    private func filteredPendingItems(from items: [PhotoReviewItem]) -> [PhotoReviewItem] {
        items.filter { item in
            guard let asset = item.asset else { return true }
            return matchesCurrentFilter(asset)
        }
    }

    private func matchesCurrentFilter(_ asset: PHAsset) -> Bool {
        switch currentTimeFilter {
        case .all:
            return true
        case let .months(months):
            guard !months.isEmpty else { return true }
            guard let date = asset.creationDate, let ym = YearMonth(date: date) else { return false }
            return months.contains(ym)
        }
    }

    private func unprocessedAssets() -> [PHAsset] {
        guard !randomizedAssets.isEmpty else { return [] }
        return randomizedAssets.filter { !processedAssetIDs.contains($0.localIdentifier) }
    }

    private func adjustedSnapshot(_ snapshot: GroupUsageSnapshot) -> GroupUsageSnapshot {
        guard isPremiumBypass else { return snapshot }
        return GroupUsageSnapshot(
            consumedInCurrentGroup: 0, // force gate-off for premium
            groupsUsedToday: 0,
            groupSize: snapshot.groupSize,
            dailyLimit: Int.max,
            lastResetDate: snapshot.lastResetDate
        )
    }

    private func handleGroupCompletionIfNeeded(rawSnapshot: GroupUsageSnapshot) {
        guard isPremiumBypass else { return }
        if rawSnapshot.consumedInCurrentGroup >= rawSnapshot.groupSize {
            premiumGroupCompleted = true
            let resetSnapshot = photoGroupTracker.startNextGroupIgnoringLimit()
            photoGroupStatus = adjustedSnapshot(resetSnapshot)
        }
    }

    func moveKeptItemsToTrash(_ items: [PhotoReviewItem], simulatedDate: Date? = nil) {
        guard !items.isEmpty else { return }
        var transferBatch: [PhotoReviewItem] = []

        for item in items {
            guard let index = keptItems.firstIndex(where: { $0.id == item.id }) else { continue }
            var updated = keptItems.remove(at: index)
            updated.meta.status = .trashed
            updated.meta.updatedAt = Date().applyingSimulatedDay(simulatedDate)
            updated.meta.isFavorite = false
            updated.meta.caption = nil
            updated.meta.categoryName = nil

            if updated.isTestItem {
                testItems[updated.id] = updated
            } else {
                Task {
                    await metaStore.upsert(updated.meta)
                    await metaStore.flush()
                }
            }

            transferBatch.append(updated)
        }

        guard !transferBatch.isEmpty else { return }
        let sorted = transferBatch.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        trashItems.insert(contentsOf: sorted, at: 0)
        syncWidgetStore()
    }

    func deleteTrashItems(_ items: [PhotoReviewItem], simulatedDate: Date? = nil) {
        guard !items.isEmpty else { return }
        let assetIdentifiers = items.compactMap { $0.asset?.localIdentifier }

        Task {
            if !assetIdentifiers.isEmpty {
                try? await deleteAssets(with: assetIdentifiers)
            }

            await MainActor.run {
                for item in items {
                    var removed = item
                    removed.meta.updatedAt = Date().applyingSimulatedDay(simulatedDate)
                    trashItems.removeAll { $0.id == item.id }
                    allAssets.removeAll { $0.localIdentifier == item.id }
                    if item.isTestItem {
                        testItems.removeValue(forKey: item.id)
                    }
                }
            }

            for item in items where !item.isTestItem {
                await metaStore.remove(for: item.id)
            }
        }
    }

    private func apply(settings: DeveloperSettings, force: Bool = false) async {
        let signature = settings.reviewTuningSignature
        if !force, let lastSignature = lastQualitySignature, lastSignature == signature {
            return
        }
        lastQualitySignature = signature

        let updatedDeck = reviewDeck.map { item -> PhotoReviewItem in
            var updated = item
            updated.quality = analyzer.quality(for: item.meta.metrics)
            return updated
        }

        let updatedKept = keptItems.map { item -> PhotoReviewItem in
            var updated = item
            updated.quality = analyzer.quality(for: item.meta.metrics)
            return updated
        }

        let updatedTrash = trashItems.map { item -> PhotoReviewItem in
            var updated = item
            updated.quality = analyzer.quality(for: item.meta.metrics)
            return updated
        }

        for item in updatedDeck + updatedKept + updatedTrash where item.isTestItem {
            testItems[item.id] = item
        }

        reviewDeck = arrangedDeck(from: updatedDeck)
        keptItems = updatedKept
        trashItems = updatedTrash
    }

    private func insertIntoDeck(_ item: PhotoReviewItem, preferFront: Bool = false) {
        reviewDeck.removeAll { $0.id == item.id }
        if preferFront {
            reviewDeck.insert(item, at: 0)
        } else {
            reviewDeck.append(item)
        }
    }

    private func applyScanResult(_ result: ScanBatchResult, replaceExisting: Bool) {
        guard !isInPhotoTutorial else {
            bufferScanResult(result)
            return
        }
        let pendingItems = filteredPendingItems(from: result.pending)
        if replaceExisting {
            if pendingItems.isEmpty && !reviewDeck.isEmpty {
                if !result.kept.isEmpty {
                    for item in result.kept {
                        keptItems.removeAll { $0.id == item.id }
                        keptItems.insert(item, at: 0)
                    }
                }
                if !result.trashed.isEmpty {
                    for item in result.trashed {
                        trashItems.removeAll { $0.id == item.id }
                        trashItems.insert(item, at: 0)
                    }
                }
                syncWidgetStore()
                return
            }

            var deck = pendingItems
            var keptSnapshot = result.kept
            var trashSnapshot = result.trashed
            injectTestItems(into: &deck, kept: &keptSnapshot, trash: &trashSnapshot)

            reviewDeck = arrangedDeck(from: deck)
            if keptItems.isEmpty {
                keptItems = keptSnapshot
            } else if !keptSnapshot.isEmpty {
                for item in keptSnapshot {
                    keptItems.removeAll { $0.id == item.id }
                    keptItems.insert(item, at: 0)
                }
            }
            if trashItems.isEmpty {
                trashItems = trashSnapshot
            } else if !trashSnapshot.isEmpty {
                for item in trashSnapshot {
                    trashItems.removeAll { $0.id == item.id }
                    trashItems.insert(item, at: 0)
                }
            }
            syncWidgetStore()
            return
        }

        if !pendingItems.isEmpty {
            reviewDeck = mergedDeck(current: reviewDeck, incoming: pendingItems)
        }

        if !result.kept.isEmpty {
            for item in result.kept {
                keptItems.removeAll { $0.id == item.id }
                keptItems.insert(item, at: 0)
            }
        }

        if !result.trashed.isEmpty {
            for item in result.trashed {
                trashItems.removeAll { $0.id == item.id }
                trashItems.insert(item, at: 0)
            }
        }
        syncWidgetStore()
    }

    private func bufferScanResult(_ result: ScanBatchResult) {
        guard !(result.pending.isEmpty && result.kept.isEmpty && result.trashed.isEmpty) else { return }

        bufferedScanResult.pending = mergeBufferedItems(
            existing: bufferedScanResult.pending,
            incoming: result.pending
        )
        bufferedScanResult.kept = mergeBufferedItems(
            existing: bufferedScanResult.kept,
            incoming: result.kept
        )
        bufferedScanResult.trashed = mergeBufferedItems(
            existing: bufferedScanResult.trashed,
            incoming: result.trashed
        )
        normalizeBufferedScanResult()
    }

    private func mergeBufferedItems(
        existing: [PhotoReviewItem],
        incoming: [PhotoReviewItem]
    ) -> [PhotoReviewItem] {
        guard !incoming.isEmpty else { return existing }
        var map = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in incoming {
            map[item.id] = item
        }
        return Array(map.values)
    }

    private func normalizeBufferedScanResult() {
        let trashedIDs = Set(bufferedScanResult.trashed.map(\.id))
        if !trashedIDs.isEmpty {
            bufferedScanResult.kept.removeAll { trashedIDs.contains($0.id) }
            bufferedScanResult.pending.removeAll { trashedIDs.contains($0.id) }
        }
        let keptIDs = Set(bufferedScanResult.kept.map(\.id))
        if !keptIDs.isEmpty {
            bufferedScanResult.pending.removeAll { keptIDs.contains($0.id) }
        }
    }

    private func applyBufferedScanResult(restoreDeck: Bool) {
        guard !(bufferedScanResult.pending.isEmpty &&
                bufferedScanResult.kept.isEmpty &&
                bufferedScanResult.trashed.isEmpty) else { return }

        let pendingItems = filteredPendingItems(from: bufferedScanResult.pending)
        if restoreDeck {
            if !pendingItems.isEmpty {
                reviewDeck = mergedDeck(current: reviewDeck, incoming: pendingItems)
            }
        } else {
            reviewDeck = pendingItems.isEmpty ? [] : arrangedDeck(from: pendingItems)
        }

        if !bufferedScanResult.kept.isEmpty {
            for item in bufferedScanResult.kept {
                keptItems.removeAll { $0.id == item.id }
                keptItems.insert(item, at: 0)
            }
        }

        if !bufferedScanResult.trashed.isEmpty {
            for item in bufferedScanResult.trashed {
                trashItems.removeAll { $0.id == item.id }
                trashItems.insert(item, at: 0)
            }
        }

        bufferedScanResult = .empty
        syncWidgetStore()
    }

    private func injectTestItems(
        into pending: inout [PhotoReviewItem],
        kept: inout [PhotoReviewItem],
        trash: inout [PhotoReviewItem]
    ) {
        guard !testItems.isEmpty else { return }

        let testValues = Array(testItems.values)
        let pendingTests = testValues.filter { $0.meta.status == .pending }
        let keptTests = testValues
            .filter { $0.meta.status == .kept }
            .sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        let trashedTests = testValues
            .filter { $0.meta.status == .trashed }
            .sorted { $0.meta.updatedAt > $1.meta.updatedAt }

        pending.append(contentsOf: pendingTests)
        kept.insert(contentsOf: keptTests, at: 0)
        trash.insert(contentsOf: trashedTests, at: 0)
    }

    private func refreshAvailableMonths(with assets: [PHAsset]) {
        monthAggregationTask?.cancel()
        guard !assets.isEmpty else {
            availableMonths = [:]
            isMonthListLoading = false
            monthAggregationTask = nil
            return
        }

        isMonthListLoading = true
        let snapshot = assets
        monthAggregationTask = Task(priority: .utility) { [weak self] in
            var counts: [YearMonth: Int] = [:]

            for asset in snapshot {
                if Task.isCancelled { return }
                guard let date = asset.creationDate, let yearMonth = YearMonth(date: date) else { continue }
                counts[yearMonth, default: 0] += 1
            }

            if Task.isCancelled { return }
            await MainActor.run {
                self?.availableMonths = counts
                self?.isMonthListLoading = false
            }
        }
    }

    private func mergeLibraryAssets(_ assets: [PHAsset], replaceExisting: Bool) {
        if replaceExisting {
            allAssets = assets
        } else {
            for asset in assets where !allAssets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                allAssets.append(asset)
            }
        }
    }

    nonisolated private func prioritizedInitialAssets(from assets: [PHAsset], limit: Int) -> [PHAsset] {
        guard !assets.isEmpty else { return [] }
        let target = min(max(limit, 0), assets.count)
        guard target > 0 else { return [] }
        return Array(assets.prefix(target))
    }

    nonisolated private func chunkAssets(_ assets: [PHAsset], chunkSize: Int) -> [[PHAsset]] {
        guard chunkSize > 0 else { return assets.isEmpty ? [] : [assets] }
        var chunks: [[PHAsset]] = []
        chunks.reserveCapacity(max(assets.count / chunkSize, 1))
        var index = 0
        while index < assets.count {
            let end = min(index + chunkSize, assets.count)
            chunks.append(Array(assets[index..<end]))
            index = end
        }
        return chunks
    }

    private func adaptiveChunkSize(_ base: Int) -> Int {
        var adjusted = base
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        if state == .charging || state == .full {
            adjusted = max(base, base * 2)
        }
        return adjusted
    }

    private func arrangedDeck(from items: [PhotoReviewItem]) -> [PhotoReviewItem] {
        stableRandomized(items)
    }

    private func mergedDeck(current: [PhotoReviewItem], incoming: [PhotoReviewItem]) -> [PhotoReviewItem] {
        guard !incoming.isEmpty else { return current }
        guard !current.isEmpty else { return stableRandomized(incoming) }

        let top = current[0]
        let next = current.count > 1 ? current[1] : nil
        let remaining = current.count > 2 ? Array(current.dropFirst(2)) : []

        let newItems = stableRandomized(
            incoming.filter { incomingItem in
                !current.contains(where: { $0.id == incomingItem.id })
            }
        )

        var merged: [PhotoReviewItem] = [top]
        if let next { merged.append(next) }
        merged.append(contentsOf: remaining)
        merged.append(contentsOf: newItems)
        return merged
    }

    private func stableRandomizedAssets(from assets: [PHAsset]) -> [PHAsset] {
        let keyed = assets.map { asset in
            (asset: asset, key: stableRandomKey(for: asset.localIdentifier))
        }
        return keyed.sorted { $0.key < $1.key }.map { $0.asset }
    }

    private func stableRandomized(_ items: [PhotoReviewItem]) -> [PhotoReviewItem] {
        let keyed = items.map { item in
            (item: item, key: stableRandomKey(for: item.id))
        }
        return keyed.sorted { $0.key < $1.key }.map { $0.item }
    }

    private func stableRandomKey(for identifier: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325 ^ randomSeed
        for byte in identifier.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    private static func loadRandomSeed(key: String) -> UInt64 {
        if let stored = UserDefaults.standard.object(forKey: key) as? NSNumber {
            return stored.uint64Value
        }
        let seed = UInt64.random(in: UInt64.min...UInt64.max)
        UserDefaults.standard.set(NSNumber(value: seed), forKey: key)
        return seed
    }

    private func loadImage(for item: PhotoReviewItem) async -> UIImage? {
        if let testImage = item.testImage?.image {
            return testImage
        }

        guard let asset = item.asset else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data, let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func deleteAssets(with identifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func flushStore() {
        Task { await metaStore.flush() }
    }

    private func bootstrapIfNeeded() async {
        let status = authorizationStatus
        guard status == .authorized || status == .limited else { return }

        await metaStore.waitUntilLoaded()
        await loadCachedStateIfNeeded()
        await scanLibrary()
        syncWidgetStore()
    }

    private func loadCachedStateIfNeeded() async {
        guard !hasLoadedCachedState else { return }
        let cachedMeta = await metaStore.allMeta()
        guard !cachedMeta.isEmpty else { return }

        let assets = await libraryManager.fetchPhotoAssetsAsync(limit: nil, sortAscending: false)
        mergeLibraryAssets(assets, replaceExisting: true)
        refreshAvailableMonths(with: assets)
        randomizedAssets = stableRandomizedAssets(from: allAssets)
        filteredAssets = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)
        processedAssetIDs = Set(cachedMeta.map(\.id))

        let metaDict = Dictionary(uniqueKeysWithValues: cachedMeta.map { ($0.id, $0) })
        var pending: [PhotoReviewItem] = []
        var kept: [PhotoReviewItem] = []
        var trashed: [PhotoReviewItem] = []

        let filteredIDs = Set(filteredAssets.map(\.localIdentifier))
        for asset in assets {
            guard let meta = metaDict[asset.localIdentifier] else { continue }
            let quality = analyzer.quality(for: meta.metrics)
            let item = PhotoReviewItem(asset: asset, meta: meta, quality: quality)

            switch meta.status {
            case .pending:
                if filteredIDs.contains(asset.localIdentifier) {
                    pending.append(item)
                }
            case .kept:
                kept.append(item)
            case .trashed:
                trashed.append(item)
            }
        }

        if !pending.isEmpty {
            reviewDeck = arrangedDeck(from: pending)
        }
        if keptItems.isEmpty {
            keptItems = kept.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        }
        if trashItems.isEmpty {
            trashItems = trashed.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        }
        let totalCount = max(allAssets.count, 1)
        scanProgress = min(1, Double(processedAssetIDs.count) / Double(totalCount))
        hasLoadedCachedState = true
        syncWidgetStore()
    }

    private func rebuildDeckFromCache(cachedMeta: [PhotoMeta], filteredAssets: [PHAsset]) async {
        guard !cachedMeta.isEmpty else {
            reviewDeck = []
            hasLoadedCachedState = true
            return
        }

        let metaDict = Dictionary(uniqueKeysWithValues: cachedMeta.map { ($0.id, $0) })
        var pending: [PhotoReviewItem] = []

        for asset in filteredAssets {
            guard let meta = metaDict[asset.localIdentifier],
                  meta.status == .pending else { continue }
            let quality = analyzer.quality(for: meta.metrics)
            let item = PhotoReviewItem(asset: asset, meta: meta, quality: quality)
            pending.append(item)
        }

        var keptSnapshot: [PhotoReviewItem] = []
        var trashSnapshot: [PhotoReviewItem] = []
        injectTestItems(into: &pending, kept: &keptSnapshot, trash: &trashSnapshot)
        reviewDeck = arrangedDeck(from: pending)
        hasLoadedCachedState = true
    }

    private func apply(timeFilter: MediaTimeFilter) async {
        let signature = Self.timeFilterSignature(timeFilter)
        if let last = lastTimeFilterSignature, last == signature {
            return
        }

        lastTimeFilterSignature = signature
        await metaStore.flush()
        currentTimeFilter = timeFilter
        if randomizedAssets.isEmpty {
            let assets = await libraryManager.fetchPhotoAssetsAsync(limit: nil, sortAscending: false)
            mergeLibraryAssets(assets, replaceExisting: true)
            refreshAvailableMonths(with: assets)
            randomizedAssets = stableRandomizedAssets(from: allAssets)
        }
        filteredAssets = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)
        let cachedMeta = await metaStore.allMeta()
        processedAssetIDs = Set(cachedMeta.map(\.id))
        await rebuildDeckFromCache(cachedMeta: cachedMeta, filteredAssets: filteredAssets)
        resumeScanningIfNeeded()
    }

    private static func timeFilterSignature(_ filter: MediaTimeFilter) -> Int {
        var hasher = Hasher()
        hasher.combine("photo-time-filter")
        switch filter {
        case .all:
            hasher.combine(0)
        case let .months(months):
            let sorted = months.sorted()
            for m in sorted {
                hasher.combine(m.year)
                hasher.combine(m.month)
            }
        }
        return hasher.finalize()
    }

    private func syncWidgetStore() {
        widgetSyncTask?.cancel()
        let settings = WidgetPhotoStore.loadPhotoWallSettings()

        widgetSyncTask = Task {
            guard self.authorizationStatus == .authorized || self.authorizationStatus == .limited else {
                return
            }

            switch settings.mode {
            case .manual:
                let identifiers = Array(settings.manualAssetIdentifiers.prefix(self.widgetManualExportLimit))
                guard !identifiers.isEmpty else { return }
                await self.buildManualWidgetSnapshot(identifiers: identifiers)
            case .daily:
                let snapshot = WidgetPhotoStore.loadSnapshot()
                if snapshot.favorites.isEmpty && snapshot.kept.isEmpty {
                    await self.buildRandomWidgetSnapshot()
                }
            }
        }
    }

    func requestPhotoWallRandomRefresh() {
        scheduleWidgetSnapshotRefresh { [weak self] in
            guard let self else { return }
            guard self.authorizationStatus == .authorized || self.authorizationStatus == .limited else { return }
            await self.buildRandomWidgetSnapshot()
        }
    }

    func performPhotoWallRandomRefresh() async -> Bool {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return false
        }
        await buildRandomWidgetSnapshot()
        return true
    }

    func requestPhotoWallManualRefresh(identifiers: [String]) {
        scheduleWidgetSnapshotRefresh { [weak self] in
            guard let self else { return }
            guard self.authorizationStatus == .authorized || self.authorizationStatus == .limited else { return }
            let limited = Array(identifiers.prefix(self.widgetManualExportLimit))
            guard !limited.isEmpty else { return }
            await self.buildManualWidgetSnapshot(identifiers: limited)
        }
    }

    private func scheduleWidgetSnapshotRefresh(_ operation: @escaping () async -> Void) {
        widgetSyncTask?.cancel()
        widgetSyncTask = Task {
            await operation()
        }
    }

    private func buildWidgetCandidates(
        from items: [PhotoReviewItem],
        favoriteOnly: Bool,
        limit: Int
    ) async -> [WidgetPhotoCandidate] {
        var seen = Set<String>()
        var result: [WidgetPhotoCandidate] = []

        for item in items {
            if Task.isCancelled { break }
            guard let asset = item.asset else { continue }
            let isFavorite = item.meta.isFavorite
            if favoriteOnly && !isFavorite { continue }
            if !favoriteOnly && isFavorite { continue }

            let identifier = asset.localIdentifier
            guard !identifier.isEmpty, !seen.contains(identifier) else { continue }
            seen.insert(identifier)

            let fileName = WidgetPhotoStore.thumbnailFileName(for: identifier)
            guard let thumbnailData = await widgetThumbnailData(for: asset, fileName: fileName) else {
                continue
            }

            let ratio = await widgetNormalizedAspectRatio(for: asset)
            result.append(
                WidgetPhotoCandidate(
                    assetIdentifier: identifier,
                    aspectRatio: ratio,
                    updatedAt: item.meta.updatedAt,
                    isFavorite: isFavorite,
                    thumbnailFileName: fileName,
                    thumbnailData: thumbnailData
                )
            )

            if result.count >= limit { break }
        }

        return result
    }

    private func buildWidgetCandidates(
        from assets: [PHAsset],
        limit: Int
    ) async -> [WidgetPhotoCandidate] {
        var result: [WidgetPhotoCandidate] = []
        result.reserveCapacity(min(limit, assets.count))

        for asset in assets {
            if Task.isCancelled { break }
            let identifier = asset.localIdentifier
            guard !identifier.isEmpty else { continue }

            let fileName = WidgetPhotoStore.thumbnailFileName(for: identifier)
            guard let thumbnailData = await widgetThumbnailData(for: asset, fileName: fileName) else {
                continue
            }

            let ratio = await widgetNormalizedAspectRatio(for: asset)
            result.append(
                WidgetPhotoCandidate(
                    assetIdentifier: identifier,
                    aspectRatio: ratio,
                    updatedAt: Date(),
                    isFavorite: false,
                    thumbnailFileName: fileName,
                    thumbnailData: thumbnailData
                )
            )

            if result.count >= limit { break }
        }

        return result
    }

    private func widgetNormalizedAspectRatio(for asset: PHAsset) async -> Double {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, orientation, _ in
                var width = Double(asset.pixelWidth)
                var height = Double(asset.pixelHeight)

                if
                    let data,
                    let source = CGImageSourceCreateWithData(data as CFData, nil),
                    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                {
                    if let value = props[kCGImagePropertyPixelWidth] as? NSNumber {
                        width = value.doubleValue
                    }
                    if let value = props[kCGImagePropertyPixelHeight] as? NSNumber {
                        height = value.doubleValue
                    }
                }

                var ratio = width / max(height, 1)
                if self.isRotatedOrientation(orientation) {
                    ratio = 1.0 / max(ratio, 0.0001)
                }

                continuation.resume(returning: self.normalizeWidgetAspectRatio(ratio))
            }
        }
    }

    private func normalizeWidgetAspectRatio(_ ratio: Double) -> Double {
        guard ratio > 0 else { return 4.0 / 3.0 }
        if ratio < 0.85 {
            return 3.0 / 4.0
        }
        if ratio < 1.15 {
            return 1.0
        }
        if ratio > 1.6 {
            return 16.0 / 9.0
        }
        return 4.0 / 3.0
    }

    private func isRotatedOrientation(_ orientation: CGImagePropertyOrientation) -> Bool {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return true
        default:
            return false
        }
    }

    private func buildRandomWidgetSnapshot() async {
        let fetchLimit = widgetSnapshotExportLimit * widgetRandomSampleMultiplier
        let randomAssets = await fetchRandomAssets(limit: fetchLimit)
        let shuffledAssets = randomAssets.shuffled()
        let kept = await buildWidgetCandidates(from: shuffledAssets, limit: widgetSnapshotExportLimit)
        WidgetPhotoStore.update(favorites: [], kept: kept)
    }

    private func buildManualWidgetSnapshot(identifiers: [String]) async {
        let assets = await fetchAssets(with: identifiers)
        let kept = await buildWidgetCandidates(from: assets, limit: identifiers.count)
        WidgetPhotoStore.update(favorites: [], kept: kept)
    }

    private func fetchAssets(with identifiers: [String]) async -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var map: [String: PHAsset] = [:]
                map.reserveCapacity(results.count)
                results.enumerateObjects { asset, _, _ in
                    map[asset.localIdentifier] = asset
                }
                let assets = identifiers.compactMap { map[$0] }
                continuation.resume(returning: assets)
            }
        }
    }

    private func fetchRandomAssets(limit: Int) async -> [PHAsset] {
        guard limit > 0 else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHFetchOptions()
                options.predicate = NSPredicate(
                    format: "(mediaSubtype & %d) == 0",
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                )
                let results = PHAsset.fetchAssets(with: .image, options: options)
                let totalCount = results.count
                guard totalCount > 0 else {
                    continuation.resume(returning: [])
                    return
                }

                let targetCount = min(limit, totalCount)
                if totalCount <= targetCount {
                    var assets: [PHAsset] = []
                    assets.reserveCapacity(totalCount)
                    results.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                    var generator = SystemRandomNumberGenerator()
                    continuation.resume(returning: assets.shuffled(using: &generator))
                    return
                }

                var indices = Set<Int>()
                indices.reserveCapacity(targetCount)
                var generator = SystemRandomNumberGenerator()
                while indices.count < targetCount {
                    indices.insert(Int.random(in: 0..<totalCount, using: &generator))
                }
                var assets = indices.map { results.object(at: $0) }
                assets.shuffle(using: &generator)
                continuation.resume(returning: assets)
            }
        }
    }

    private func widgetThumbnailData(for asset: PHAsset, fileName: String) async -> Data? {
        if let url = WidgetPhotoStore.thumbnailURL(for: fileName),
           let data = try? Data(contentsOf: url) {
            return data
        }

        guard let image = await requestWidgetThumbnail(for: asset) else { return nil }
        guard let data = image.jpegData(compressionQuality: widgetThumbnailQuality) else { return nil }

        if let url = WidgetPhotoStore.thumbnailURL(for: fileName) {
            try? data.write(to: url, options: [.atomic])
        }
        return data
    }

    private func requestWidgetThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: widgetThumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

private struct PhotoScanWorker: Sendable {
    let analyzer: PhotoAnalyzer
    let metaStore: PhotoMetaStore
    let allowNetworkAccess: Bool

    func processAssets(
        _ assets: [PHAsset],
        startingProcessedIDs: Set<String>
    ) async -> PhotoReviewViewModel.ScanTaskOutput {
        guard !assets.isEmpty else {
            return PhotoReviewViewModel.ScanTaskOutput(result: .empty, processedIdentifiers: startingProcessedIDs)
        }

        var processedIdentifiers = startingProcessedIDs
        analyzer.prepareForScan(assets: assets, allowNetworkAccess: allowNetworkAccess)
        defer { analyzer.finishScan(assets: assets, allowNetworkAccess: allowNetworkAccess) }

        var pending: [PhotoReviewItem] = []
        var kept: [PhotoReviewItem] = []
        var trashed: [PhotoReviewItem] = []

        for (index, asset) in assets.enumerated() {
            if Task.isCancelled { break }
            let identifier = asset.localIdentifier
            if processedIdentifiers.contains(identifier) {
                continue
            }

            var meta = await metaStore.meta(for: identifier)

            if meta == nil {
                let metrics = await analyzer.analyze(asset: asset, allowNetworkAccess: allowNetworkAccess)
                if metrics == nil && !allowNetworkAccess {
                    continue
                }
                let now = Date()
                let newMeta = PhotoMeta(
                    id: identifier,
                    metrics: metrics ?? PhotoMetrics(),
                    status: .pending,
                    createdAt: now,
                    updatedAt: now,
                    isFavorite: false
                )
                meta = newMeta
                await metaStore.upsert(newMeta)
            }

            guard let resolvedMeta = meta else { continue }
            processedIdentifiers.insert(identifier)
            let quality = analyzer.quality(for: resolvedMeta.metrics)
            let item = PhotoReviewItem(asset: asset, meta: resolvedMeta, quality: quality)

            switch resolvedMeta.status {
            case .pending:
                pending.append(item)
            case .kept:
                kept.append(item)
            case .trashed:
                trashed.append(item)
            }

            if index.isMultiple(of: 25) {
                await Task.yield()
            }
        }

        await metaStore.flush()

        kept.sort { $0.meta.updatedAt > $1.meta.updatedAt }
        trashed.sort { $0.meta.updatedAt > $1.meta.updatedAt }

        let result = PhotoReviewViewModel.ScanBatchResult(pending: pending, kept: kept, trashed: trashed)
        return PhotoReviewViewModel.ScanTaskOutput(result: result, processedIdentifiers: processedIdentifiers)
    }
}
