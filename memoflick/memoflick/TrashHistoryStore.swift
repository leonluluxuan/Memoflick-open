//
//  TrashHistoryStore.swift
//  memoflick
//
//  Created by Codex on 2026/01/07.
//

import Foundation
import Photos
import UIKit
import Combine

struct TrashDayRecord: Codable {
    let dateKey: String
    var totalCount: Int
    var totalBytes: Int64
    var thumbnailData: Data?
    var lastUpdated: Date

    var date: Date {
        TrashHistoryStore.dateFormatter.date(from: dateKey) ?? Date()
    }
}

@MainActor
final class TrashHistoryStore: ObservableObject {
    static let shared = TrashHistoryStore()

    private let defaultsKey = "trash_day_records"
    @Published private(set) var records: [String: TrashDayRecord] = [:]
    private let imageManager = PHCachingImageManager()
    private let sizeStore = AssetSizeStore.shared

    init() {
        load()
    }

    func record(items: [AlbumMediaItem], on date: Date = Date()) {
        guard !items.isEmpty else { return }
        let key = Self.key(for: date)
        let legacyKey = Self.legacyKey(for: date)
        var record = records[key] ?? records[legacyKey] ?? TrashDayRecord(dateKey: key, totalCount: 0, totalBytes: 0, thumbnailData: nil, lastUpdated: date)

        record.totalCount += items.count
        var pendingAssetIDs: [String] = []
        let addedBytes = items.reduce(Int64(0)) { partial, item in
            if let size = resolvedBytes(for: item) {
                return partial + size
            }
            if let assetID = item.asset?.localIdentifier {
                pendingAssetIDs.append(assetID)
            }
            return partial
        }
        record.totalBytes += addedBytes
        record.lastUpdated = date

        if shouldSetInitialThumbnail(for: record), let firstItem = items.first {
            fetchThumbnailAsync(for: firstItem, recordKey: key)
        }

        records[key] = record
        if legacyKey != key {
            records[legacyKey] = nil
        }
        persist()

        for assetID in pendingAssetIDs {
            resolveAndAppendSize(assetID: assetID, recordKey: key)
        }
    }

    func record(for date: Date) -> TrashDayRecord? {
        let key = Self.key(for: date)
        if let record = records[key] {
            return record
        }
        let legacyKey = Self.legacyKey(for: date)
        return records[legacyKey]
    }

    var allRecords: [TrashDayRecord] {
        Array(records.values)
    }

    // MARK: - Helpers

    private func resolvedBytes(for item: AlbumMediaItem) -> Int64? {
        if let size = item.compressedSizeBytes {
            return size
        }
        if let asset = item.asset,
           let cached = sizeStore.cachedSize(for: asset.localIdentifier) {
            return cached
        }
        if let testImage = item.testImage?.image {
            let pixels = Int(testImage.size.width * testImage.size.height)
            return Int64(pixels * 4)
        }
        return nil
    }

    private func resolveAndAppendSize(assetID: String, recordKey: String) {
        sizeStore.requestSizeIfNeeded(for: assetID, allowNetworkAccess: true) { [weak self] size in
            guard let self, let size else { return }
            guard var record = self.records[recordKey] else { return }
            record.totalBytes += size
            record.lastUpdated = Date()
            self.records[recordKey] = record
            self.persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([String: TrashDayRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func shouldSetInitialThumbnail(for record: TrashDayRecord) -> Bool {
        record.thumbnailData == nil
    }

    private func fetchThumbnailAsync(for item: AlbumMediaItem, recordKey: String) {
        if let test = item.testImage?.image, let data = test.pngData() {
            records[recordKey]?.thumbnailData = data
            persist()
            return
        }
        guard let asset = item.asset else { return }

        let target = CGSize(width: 200, height: 200)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let self, let image, let data = image.pngData() else { return }
            Task { @MainActor in
                if var existing = self.records[recordKey], existing.thumbnailData == nil {
                    existing.thumbnailData = data
                    self.records[recordKey] = existing
                    self.persist()
                }
            }
        }
    }

    static func key(for date: Date) -> String {
        let normalized = normalizedMidday(for: date)
        return dateFormatter.string(from: normalized)
    }

    static func legacyKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static func normalizedMidday(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: components.year, month: components.month, day: components.day, hour: 12)) ?? date
    }

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
