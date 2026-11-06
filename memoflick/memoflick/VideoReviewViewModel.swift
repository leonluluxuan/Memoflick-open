//
//  VideoReviewViewModel.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import Foundation
import Combine
import Photos
import UIKit

@MainActor
final class VideoReviewViewModel: ObservableObject {
    enum SwipeAction {
        case keep
        case delete
    }

    @Published private(set) var authorizationStatus: PHAuthorizationStatus
    @Published private(set) var deck: [VideoReviewItem] = []
    @Published private(set) var keptItems: [VideoReviewItem] = []
    @Published private(set) var trashItems: [VideoReviewItem] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published private(set) var hasInitialBatchReady = false
    @Published private(set) var groupStatus: GroupUsageSnapshot
    @Published private(set) var currentGroupClearedBytes: Int64 = 0
    @Published var isPremiumBypass = true
    @Published var premiumGroupCompleted: Bool = false
    @Published private(set) var availableMonths: [YearMonth: Int] = [:]
    @Published var isMonthListLoading = false
    private var historyStack: [VideoReviewItem] = []
    private var backgroundScanTask: Task<Void, Never>?
    private var pendingBackgroundAssets: [PHAsset] = []
    private var monthAggregationTask: Task<Void, Never>?
    private var filteredAssets: [PHAsset] = []
    private var allAssets: [PHAsset] = []
    private var randomizedAssets: [PHAsset] = []
    private var processedAssetIDs = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    var currentVideo: VideoReviewItem? { deck.first }
    var nextVideo: VideoReviewItem? {
        guard deck.count > 1 else { return nil }
        return deck[1]
    }
    var hasNextVideo: Bool { !deck.isEmpty && (!groupStatus.isGateActive || isPremiumBypass) }
    var hasPreviousVideo: Bool { !historyStack.isEmpty }
    var previousVideo: VideoReviewItem? { historyStack.last }
    var isUsingTimeFilter: Bool {
        if case .all = currentTimeFilter { return false }
        return true
    }

    private let libraryManager = PhotoLibraryManager()
    private let metaStore = VideoMetaStore()
    private let sizeStore: AssetSizeStore
    private var hasBootstrapped = false
    private let userSettingsStore: UserSettingsStore
    private var currentTimeFilter: MediaTimeFilter
    private var lastTimeFilterSignature: Int?
    private let initialVideoBatchCount = 30
    private let videoChunkSize = 30
    private let randomSeed = VideoReviewViewModel.loadRandomSeed(key: "video_random_seed")
    private let videoGroupConfig = ReviewGroupTracker.Config(
        groupSize: 10,
        dailyLimit: 2,
        storageKey: "video-review-group"
    )
    private let groupTracker: ReviewGroupTracker
    private var clearedSizeByItemID: [String: Int64] = [:]
    private var pendingClearedSizeIDs: Set<String> = []

    init(
        userSettingsStore: UserSettingsStore,
        sizeStore: AssetSizeStore? = nil
    ) {
        let tracker = ReviewGroupTracker(config: videoGroupConfig)
        groupTracker = tracker
        groupStatus = tracker.currentStatus()
        authorizationStatus = libraryManager.currentAuthorizationStatus()
        self.userSettingsStore = userSettingsStore
        self.sizeStore = sizeStore ?? AssetSizeStore.shared
        currentTimeFilter = userSettingsStore.current.videoTimeFilter
        Task { await bootstrapIfNeeded() }

        userSettingsStore.$current
            .map { $0.videoTimeFilter }
            .removeDuplicates { lhs, rhs in
                Self.timeFilterSignature(lhs) == Self.timeFilterSignature(rhs)
            }
            .sink { [weak self] newFilter in
                Task { await self?.apply(timeFilter: newFilter) }
            }
            .store(in: &cancellables)
    }

    deinit {
        backgroundScanTask?.cancel()
        monthAggregationTask?.cancel()
    }

    func refreshGroupStatus() {
        groupStatus = adjustedSnapshot(groupTracker.currentStatus())
    }

    func resetTimeFilterToAll() {
        userSettingsStore.current.photoTimeFilter = .all
        userSettingsStore.current.videoTimeFilter = .all
    }

    func pauseScanning() {
        backgroundScanTask?.cancel()
        backgroundScanTask = nil
        isScanning = false
    }

    func flushStore() {
        Task { await metaStore.flush() }
    }

    func resumeScanningIfNeeded() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        guard !isScanning else { return }
        let remaining = unprocessedAssets()
        guard !remaining.isEmpty else { return }

        let worker = VideoScanWorker(metaStore: metaStore)
        let chunk = adaptiveChunkSize(videoChunkSize)
        isScanning = true
        backgroundScanTask = Task { [weak self] in
            guard let self else { return }
            await self.processAssets(
                remaining,
                total: max(self.allAssets.count, 1),
                replaceExisting: false,
                worker: worker,
                chunkSize: chunk
            )
            await MainActor.run {
                self.backgroundScanTask = nil
                self.isScanning = false
            }
        }
    }

    func startNextGroupIfAvailable() {
        let snapshot = isPremiumBypass
            ? groupTracker.startNextGroupIgnoringLimit()
            : groupTracker.startNextGroupIfAvailable()
        groupStatus = adjustedSnapshot(snapshot)
        currentGroupClearedBytes = 0
        clearedSizeByItemID.removeAll()
        pendingClearedSizeIDs.removeAll()
    }

    func requestAccessIfNeeded() async {
        let status = authorizationStatus
        if status == .notDetermined {
            let newStatus = await libraryManager.requestAuthorization()
            authorizationStatus = newStatus
            await bootstrapIfNeeded()
        } else if status == .authorized || status == .limited {
            await bootstrapIfNeeded()
        }
    }

    func refreshIfNeeded() async {
        guard !isScanning else { return }
        await scanLibrary(force: true)
    }

    private func loadCachedStateIfNeeded(with assets: [PHAsset], filteredAssets: [PHAsset]) async {
        let cachedMeta = await metaStore.allMeta()
        guard !cachedMeta.isEmpty else { return }
        let metaDict = Dictionary(uniqueKeysWithValues: cachedMeta.map { ($0.id, $0) })
        processedAssetIDs = Set(cachedMeta.map(\.id))

        var pending: [VideoReviewItem] = []
        var kept: [VideoReviewItem] = []
        var trashed: [VideoReviewItem] = []

        for asset in filteredAssets {
            guard let meta = metaDict[asset.localIdentifier], meta.status == .pending else { continue }
            let item = VideoReviewItem(asset: asset, meta: meta)
            pending.append(item)
        }
        for asset in assets {
            guard let meta = metaDict[asset.localIdentifier],
                  meta.status != .pending else { continue }
            let item = VideoReviewItem(asset: asset, meta: meta)
            switch meta.status {
            case .kept:
                kept.append(item)
            case .trashed:
                trashed.append(item)
            case .pending:
                break
            }
        }

        if !pending.isEmpty {
            deck = arrangedDeck(from: pending)
        }
        if keptItems.isEmpty, !kept.isEmpty {
            keptItems = kept.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        }
        if trashItems.isEmpty, !trashed.isEmpty {
            trashItems = trashed.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        }
    }

    private func loadCachedStateIfNeeded() async {
        let cachedMeta = await metaStore.allMeta()
        guard !cachedMeta.isEmpty else { return }
        let assets = await libraryManager.fetchVideoAssetsAsync(sortAscending: false)
        allAssets = assets
        refreshAvailableMonths(with: assets)
        randomizedAssets = stableRandomizedAssets(from: allAssets)
        let filteredSnapshot = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)
        filteredAssets = filteredSnapshot
        await loadCachedStateIfNeeded(with: assets, filteredAssets: filteredSnapshot)
    }

    private func rebuildDeckFromCache(cachedMeta: [VideoMeta], filteredAssets: [PHAsset]) async {
        guard !cachedMeta.isEmpty else {
            deck = []
            return
        }

        let metaDict = Dictionary(uniqueKeysWithValues: cachedMeta.map { ($0.id, $0) })
        var pending: [VideoReviewItem] = []

        for asset in filteredAssets {
            guard let meta = metaDict[asset.localIdentifier], meta.status == .pending else { continue }
            let item = VideoReviewItem(asset: asset, meta: meta)
            pending.append(item)
        }

        if !pending.isEmpty {
            deck = arrangedDeck(from: pending)
        } else {
            deck = []
        }
    }

    @discardableResult
    func keepCurrent(favoriteMetadata: FavoriteMetadata? = nil) -> VideoReviewItem? {
        guard !(groupStatus.isGateActive && !isPremiumBypass) else { return nil }
        guard var item = deck.first else { return nil }
        deck.removeFirst()
        item.meta.status = .kept
        if let favoriteMetadata {
            let sanitized = favoriteMetadata.sanitized()
            item.meta.isFavorite = true
            item.meta.caption = sanitized.caption
            item.meta.categoryName = sanitized.categoryName
        } else {
            item.meta.isFavorite = false
            item.meta.caption = nil
            item.meta.categoryName = nil
        }
        item.meta.updatedAt = Date()
        keptItems.removeAll { $0.id == item.id }
        keptItems.insert(item, at: 0)
        Task {
            await metaStore.upsert(item.meta)
            await metaStore.flush()
        }
        let snapshot = groupTracker.registerConsumption()
        handleGroupCompletionIfNeeded(rawSnapshot: snapshot)
        groupStatus = adjustedSnapshot(snapshot)
        return item
    }

    func deleteCurrent() {
        guard !(groupStatus.isGateActive && !isPremiumBypass) else { return }
        guard var item = deck.first else { return }
        deck.removeFirst()
        item.meta.status = .trashed
        item.meta.isFavorite = false
        item.meta.caption = nil
        item.meta.categoryName = nil
        item.meta.updatedAt = Date()
        keptItems.removeAll { $0.id == item.id }
        trashItems.removeAll { $0.id == item.id }
        trashItems.insert(item, at: 0)
        historyStack.removeAll { $0.id == item.id }
        Task {
            await metaStore.upsert(item.meta)
            await metaStore.flush()
        }
        trackClearedBytes(for: item)
        let snapshot = groupTracker.registerConsumption()
        handleGroupCompletionIfNeeded(rawSnapshot: snapshot)
        groupStatus = adjustedSnapshot(snapshot)
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
        }
    }

    func restoreFromTrash(_ item: VideoReviewItem) {
        trashItems.removeAll { $0.id == item.id }
        var restored = item
        restored.meta.status = .pending
        restored.meta.updatedAt = Date()
        restored.meta.isFavorite = false
        restored.meta.caption = nil
        restored.meta.categoryName = nil
        insertIntoDeck(restored, preferFront: true)
        historyStack.removeAll { $0.id == restored.id }

        Task {
            await metaStore.upsert(restored.meta)
            await metaStore.flush()
        }
    }

    func restoreFromTrash(items: [VideoReviewItem]) {
        guard !items.isEmpty else { return }
        for item in items {
            restoreFromTrash(item)
        }
    }

    func moveKeptItemsToTrash(_ items: [VideoReviewItem], simulatedDate: Date? = nil) {
        guard !items.isEmpty else { return }
        var transferBatch: [VideoReviewItem] = []

        for item in items {
            guard let index = keptItems.firstIndex(where: { $0.id == item.id }) else { continue }
            var updated = keptItems.remove(at: index)
            updated.meta.status = .trashed
            updated.meta.updatedAt = Date().applyingSimulatedDay(simulatedDate)
            updated.meta.isFavorite = false
            updated.meta.caption = nil
            updated.meta.categoryName = nil
            transferBatch.append(updated)

            Task {
                await metaStore.upsert(updated.meta)
                await metaStore.flush()
            }
        }

        guard !transferBatch.isEmpty else { return }
        let sorted = transferBatch.sorted { $0.meta.updatedAt > $1.meta.updatedAt }
        trashItems.insert(contentsOf: sorted, at: 0)
    }

    func deleteTrashItems(_ items: [VideoReviewItem], simulatedDate: Date? = nil) {
        guard !items.isEmpty else { return }
        let assetIdentifiers = items.map(\.id)

        Task {
            if !assetIdentifiers.isEmpty {
                try? await deleteAssets(with: assetIdentifiers)
            }

            await MainActor.run {
                for item in items {
                    var updated = item
                    updated.meta.updatedAt = Date().applyingSimulatedDay(simulatedDate)
                    trashItems.removeAll { $0.id == item.id }
                    historyStack.removeAll { $0.id == item.id }
                    deck.removeAll { $0.id == item.id }
                    keptItems.removeAll { $0.id == item.id }
                }
            }

            for item in items {
                await metaStore.remove(for: item.id)
            }
        }
    }

    func toggleFavoriteForCurrent() {
        guard var item = deck.first else { return }
        item.meta.isFavorite.toggle()
        if item.meta.isFavorite == false {
            item.meta.caption = nil
            item.meta.categoryName = nil
        }
        Task {
            await metaStore.upsert(item.meta)
            await metaStore.flush()
        }
        deck[0] = item
    }

    func exportCurrentVideo() async -> URL? {
        guard let asset = currentVideo?.asset else { return nil }
        return await export(asset: asset)
    }

    func advanceToNextVideo() -> Bool {
        guard let kept = keepCurrent() else { return false }
        historyStack.append(kept)
        return true
    }

    func showPreviousVideo() -> Bool {
        guard let previous = historyStack.popLast() else { return false }
        deck.removeAll { $0.id == previous.id }
        deck.insert(previous, at: 0)
        return true
    }
}

extension VideoReviewViewModel {
    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await metaStore.waitUntilLoaded()
        await loadCachedStateIfNeeded()
        await scanLibrary()
    }

    func scanLibrary(force: Bool = false) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        if isScanning { return }
        await metaStore.waitUntilLoaded()
        refreshGroupStatus()

        backgroundScanTask?.cancel()
        backgroundScanTask = nil
        pendingBackgroundAssets.removeAll()

        if force {
            deck.removeAll()
            hasInitialBatchReady = false
            historyStack.removeAll()
        }

        isScanning = true
        scanProgress = 0

        let assets = await libraryManager.fetchVideoAssetsAsync(sortAscending: false)
        allAssets = assets
        refreshAvailableMonths(with: assets)
        randomizedAssets = stableRandomizedAssets(from: allAssets)
        let filteredSnapshot = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)
        await loadCachedStateIfNeeded(with: assets, filteredAssets: filteredSnapshot)
        filteredAssets = filteredSnapshot
        if processedAssetIDs.isEmpty {
            let cachedMeta = await metaStore.allMeta()
            processedAssetIDs = Set(cachedMeta.map(\.id))
        }

        let remaining = unprocessedAssets()
        guard !remaining.isEmpty else {
            scanProgress = min(1, Double(processedAssetIDs.count) / Double(max(allAssets.count, 1)))
            isScanning = false
            return
        }

        let total = max(allAssets.count, 1)
        let initialBatch = Array(remaining.prefix(initialVideoBatchCount))
        let pendingRemaining = Array(remaining.dropFirst(initialBatch.count))
        let worker = VideoScanWorker(metaStore: metaStore)

        await processAssets(
            initialBatch,
            total: total,
            replaceExisting: deck.isEmpty,
            worker: worker,
            chunkSize: adaptiveChunkSize(videoChunkSize)
        )
        hasInitialBatchReady = true

        guard !pendingRemaining.isEmpty else {
            scanProgress = min(1, Double(processedAssetIDs.count) / Double(total))
            isScanning = false
            return
        }

        pendingBackgroundAssets = pendingRemaining
        backgroundScanTask = Task { [weak self] in
            guard let self else { return }
            await self.processAssets(
                pendingRemaining,
                total: total,
                replaceExisting: false,
                worker: worker,
                chunkSize: self.adaptiveChunkSize(self.videoChunkSize)
            )
            await MainActor.run {
                self.pendingBackgroundAssets.removeAll()
                self.backgroundScanTask = nil
                self.isScanning = false
            }
        }
    }

    func mergeDeck(initial newItems: [VideoReviewItem]) -> [VideoReviewItem] {
        guard !newItems.isEmpty else { return [] }
        return arrangedDeck(from: newItems)
    }

    func appendPendingItems(to existing: [VideoReviewItem], newItems: [VideoReviewItem]) -> [VideoReviewItem] {
        guard !newItems.isEmpty else { return existing }
        var identifiers = Set(existing.map { $0.id })
        var merged = existing

        for item in newItems where !identifiers.contains(item.id) {
            merged.append(item)
            identifiers.insert(item.id)
        }

        guard !merged.isEmpty else { return merged }
        let currentItem = merged[0]
        let remainder = stableRandomized(Array(merged.dropFirst()))
        return [currentItem] + remainder
    }

    func mergeLibrary(existing: [VideoReviewItem], with newItems: [VideoReviewItem]) -> [VideoReviewItem] {
        guard !newItems.isEmpty else { return existing }
        var merged = existing

        for item in newItems.sorted(by: { $0.meta.updatedAt > $1.meta.updatedAt }) {
            merged.removeAll { $0.id == item.id }
            merged.insert(item, at: 0)
        }

        return merged
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

    nonisolated private func processAssets(
        _ assets: [PHAsset],
        total: Int,
        replaceExisting: Bool,
        worker: VideoScanWorker,
        chunkSize: Int
    ) async {
        guard !assets.isEmpty else { return }
        let chunks = chunkAssets(assets, chunkSize: chunkSize)
        var localProcessedIDs = await MainActor.run { self.processedAssetIDs }
        var shouldReplace = replaceExisting

        for chunk in chunks {
            if Task.isCancelled { break }
            let chunkToProcess = chunk.filter { !localProcessedIDs.contains($0.localIdentifier) }
            if chunkToProcess.isEmpty { continue }
            let output = await worker.processAssets(chunkToProcess, startingProcessedIDs: localProcessedIDs)
            localProcessedIDs = output.processedIdentifiers
            let progress = Double(localProcessedIDs.count) / Double(max(total, 1))
            let replaceNow = shouldReplace
            let processedIDsSnapshot = localProcessedIDs
            await MainActor.run {
                self.processedAssetIDs = processedIDsSnapshot
                self.applyVideoScanResult(output.result, replaceExisting: replaceNow)
                self.scanProgress = progress
            }
            shouldReplace = false
        }
    }

    @MainActor
    private func applyVideoScanResult(_ result: VideoScanWorker.BatchResult, replaceExisting: Bool) {
        if replaceExisting {
            deck = mergeDeck(initial: filteredPendingItems(from: result.pending))
            keptItems = mergeLibrary(existing: keptItems, with: result.kept)
            trashItems = mergeLibrary(existing: trashItems, with: result.trashed)
            return
        }

        let pendingItems = filteredPendingItems(from: result.pending)
        if !pendingItems.isEmpty {
            deck = appendPendingItems(to: deck, newItems: pendingItems)
        }
        keptItems = mergeLibrary(existing: keptItems, with: result.kept)
        trashItems = mergeLibrary(existing: trashItems, with: result.trashed)
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

    func insertIntoDeck(_ item: VideoReviewItem, preferFront: Bool = false) {
        deck.removeAll { $0.id == item.id }
        if preferFront {
            deck.insert(item, at: 0)
        } else {
            deck.append(item)
        }
    }

    func shuffledDeck(from deck: [VideoReviewItem]) -> [VideoReviewItem] {
        arrangedDeck(from: deck)
    }

    private func arrangedDeck(from items: [VideoReviewItem]) -> [VideoReviewItem] {
        stableRandomized(items)
    }

    private func stableRandomizedAssets(from assets: [PHAsset]) -> [PHAsset] {
        let keyed = assets.map { asset in
            (asset: asset, key: stableRandomKey(for: asset.localIdentifier))
        }
        return keyed.sorted { $0.key < $1.key }.map { $0.asset }
    }

    private func stableRandomized(_ items: [VideoReviewItem]) -> [VideoReviewItem] {
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

    func export(asset: PHAsset) async -> URL? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video }) ?? resources.first else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("memoflick-video-\(UUID().uuidString).mov")

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { error in
                if let error {
                    try? FileManager.default.removeItem(at: tempURL)
                    print("Video export failed: \(error)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: tempURL)
                }
            }
        }
    }

    func deleteAssets(with identifiers: [String]) async throws {
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

    private func filteredPendingItems(from items: [VideoReviewItem]) -> [VideoReviewItem] {
        items.filter { item in
            matchesCurrentFilter(item.asset)
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

    private func trackClearedBytes(for item: VideoReviewItem) {
        let itemID = item.id
        let assetID = item.asset.localIdentifier
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

    func updatePremiumBypass(_ isPremium: Bool) {
        isPremiumBypass = isPremium
        if !isPremium {
            premiumGroupCompleted = false
        }
        groupStatus = adjustedSnapshot(groupStatus)
    }

    func adjustedSnapshot(_ snapshot: GroupUsageSnapshot) -> GroupUsageSnapshot {
        guard isPremiumBypass else { return snapshot }
        return GroupUsageSnapshot(
            consumedInCurrentGroup: 0, // force gate-off for premium
            groupsUsedToday: 0,
            groupSize: snapshot.groupSize,
            dailyLimit: Int.max,
            lastResetDate: snapshot.lastResetDate
        )
    }

    func handleGroupCompletionIfNeeded(rawSnapshot: GroupUsageSnapshot) {
        guard isPremiumBypass else { return }
        if rawSnapshot.consumedInCurrentGroup >= rawSnapshot.groupSize {
            premiumGroupCompleted = true
            let resetSnapshot = groupTracker.startNextGroupIgnoringLimit()
            groupStatus = adjustedSnapshot(resetSnapshot)
        }
    }

    private func apply(timeFilter: MediaTimeFilter) async {
        let signature = Self.timeFilterSignature(timeFilter)
        if let last = lastTimeFilterSignature, last == signature {
            return
        }
        lastTimeFilterSignature = signature
        await metaStore.flush()
        currentTimeFilter = timeFilter
        historyStack.removeAll()
        if randomizedAssets.isEmpty {
            let assets = await libraryManager.fetchVideoAssetsAsync(sortAscending: false)
            allAssets = assets
            refreshAvailableMonths(with: assets)
            randomizedAssets = stableRandomizedAssets(from: allAssets)
        }
        filteredAssets = filteredRandomAssets(from: randomizedAssets, using: currentTimeFilter)
        let cachedMeta = await metaStore.allMeta()
        processedAssetIDs = Set(cachedMeta.map(\.id))
        await rebuildDeckFromCache(cachedMeta: cachedMeta, filteredAssets: filteredAssets)
        await resumeScanningIfNeeded()
    }

    private static func timeFilterSignature(_ filter: MediaTimeFilter) -> Int {
        var hasher = Hasher()
        hasher.combine("video-time-filter")
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

    private func adaptiveChunkSize(_ base: Int) -> Int {
        var adjusted = base
        UIDevice.current.isBatteryMonitoringEnabled = true
        let state = UIDevice.current.batteryState
        if state == .charging || state == .full {
            adjusted = max(base, base * 2)
        }
        return adjusted
    }
}

private struct VideoScanWorker: Sendable {
    struct BatchResult: Sendable {
        var pending: [VideoReviewItem]
        var kept: [VideoReviewItem]
        var trashed: [VideoReviewItem]

        static let empty = BatchResult(pending: [], kept: [], trashed: [])
    }

    struct BatchOutput: Sendable {
        var result: BatchResult
        var processedIdentifiers: Set<String>
    }

    let metaStore: VideoMetaStore

    func processAssets(
        _ assets: [PHAsset],
        startingProcessedIDs: Set<String>
    ) async -> BatchOutput {
        guard !assets.isEmpty else {
            return BatchOutput(result: .empty, processedIdentifiers: startingProcessedIDs)
        }

        var processedIdentifiers = startingProcessedIDs
        var pending: [VideoReviewItem] = []
        var kept: [VideoReviewItem] = []
        var trashed: [VideoReviewItem] = []

        for (index, asset) in assets.enumerated() {
            if Task.isCancelled { break }
            let identifier = asset.localIdentifier
            if processedIdentifiers.contains(identifier) {
                continue
            }
            var meta = await metaStore.meta(for: identifier)

            if meta == nil {
                let now = Date()
                let newMeta = VideoMeta(
                    id: identifier,
                    status: .pending,
                    createdAt: asset.creationDate ?? now,
                    updatedAt: now,
                    duration: asset.duration,
                    isFavorite: false
                )
                await metaStore.upsert(newMeta)
                meta = newMeta
            }

            guard let resolvedMeta = meta else { continue }
            processedIdentifiers.insert(identifier)
            let item = VideoReviewItem(asset: asset, meta: resolvedMeta)

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

        let result = BatchResult(pending: pending, kept: kept, trashed: trashed)
        return BatchOutput(result: result, processedIdentifiers: processedIdentifiers)
    }
}
