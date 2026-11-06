import Foundation
import Combine
import WidgetKit
import UIKit

struct WidgetPhotoCandidate: Codable, Hashable {
    let assetIdentifier: String
    let aspectRatio: Double
    let updatedAt: Date
    let isFavorite: Bool
    let thumbnailFileName: String?
    let thumbnailData: Data?
}

struct WidgetPhotoSnapshot: Codable {
    var favorites: [WidgetPhotoCandidate]
    var kept: [WidgetPhotoCandidate]
    var refreshToken: String
    var updatedAt: Date
}

enum PhotoWallWidgetKind {
    static let name = "PhotoWallWidget"
}

enum WidgetPhotoStore {
    static let appGroupID = "group.com.example.memoflick.app"
    private static let snapshotKey = "photo_wall_snapshot_v1"
    private static let thumbnailDirectoryName = "PhotoWallThumbs"
    private static let backgroundDirectoryName = "PhotoWallBackgrounds"
    private static let photoWallSettingsKey = "photo_wall_settings_v1"
    private static let photoWallBackgroundDataKey = "photo_wall_background_data_v1"
    private static let pendingOpenSettingsKey = "photo_wall_pending_open_settings_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func loadSnapshot() -> WidgetPhotoSnapshot {
        guard
            let defaults,
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetPhotoSnapshot.self, from: data)
        else {
            return WidgetPhotoSnapshot(
                favorites: [],
                kept: [],
                refreshToken: UUID().uuidString,
                updatedAt: Date()
            )
        }
        return snapshot
    }

    static func thumbnailFileName(for assetIdentifier: String) -> String {
        let hash = stableHash(assetIdentifier)
        return String(format: "thumb_%016llx.jpg", hash)
    }

    static func thumbnailURL(for fileName: String) -> URL? {
        guard let directory = ensureThumbnailDirectory() else { return nil }
        return directory.appendingPathComponent(fileName)
    }

    private static func ensureThumbnailDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = containerURL.appendingPathComponent(thumbnailDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func ensureBackgroundDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = containerURL.appendingPathComponent(backgroundDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func saveSnapshot(_ snapshot: WidgetPhotoSnapshot) {
        guard
            let defaults,
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func update(favorites: [WidgetPhotoCandidate], kept: [WidgetPhotoCandidate]) {
        var snapshot = loadSnapshot()
        snapshot.favorites = favorites
        snapshot.kept = kept
        snapshot.updatedAt = Date()
        if snapshot.refreshToken.isEmpty {
            snapshot.refreshToken = UUID().uuidString
        }
        saveSnapshot(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: PhotoWallWidgetKind.name)
    }

    static func refreshToken() -> String {
        let snapshot = loadSnapshot()
        if snapshot.refreshToken.isEmpty {
            var updated = snapshot
            updated.refreshToken = UUID().uuidString
            updated.updatedAt = Date()
            saveSnapshot(updated)
            return updated.refreshToken
        }
        return snapshot.refreshToken
    }

    static func bumpRefreshToken() {
        var snapshot = loadSnapshot()
        snapshot.refreshToken = UUID().uuidString
        snapshot.updatedAt = Date()
        saveSnapshot(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: PhotoWallWidgetKind.name)
    }

    static func loadPhotoWallSettings() -> PhotoWallSettings {
        guard
            let defaults,
            let data = defaults.data(forKey: photoWallSettingsKey),
            let settings = try? JSONDecoder().decode(PhotoWallSettings.self, from: data)
        else {
            return PhotoWallSettings()
        }
        return settings
    }

    static func savePhotoWallSettings(_ settings: PhotoWallSettings) {
        guard
            let defaults,
            let data = try? JSONEncoder().encode(settings)
        else { return }
        defaults.set(data, forKey: photoWallSettingsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: PhotoWallWidgetKind.name)
    }

    static func savePhotoWallBackgroundImage(_ image: UIImage, storeToDefaults: Bool = true) -> String? {
        guard let data = scaledBackgroundData(from: image) else { return nil }
        if storeToDefaults {
            defaults?.set(data, forKey: photoWallBackgroundDataKey)
        }
        let fileName = "bg_\(UUID().uuidString).jpg"
        if let directory = ensureBackgroundDirectory() {
            let url = directory.appendingPathComponent(fileName)
            try? data.write(to: url, options: [.atomic])
        }
        return fileName
    }

    static func photoWallBackgroundData(for fileName: String) -> Data? {
        guard let directory = ensureBackgroundDirectory() else { return nil }
        let url = directory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    static func photoWallBackgroundData() -> Data? {
        defaults?.data(forKey: photoWallBackgroundDataKey)
    }

    static func clearPhotoWallBackgroundData() {
        defaults?.removeObject(forKey: photoWallBackgroundDataKey)
    }

    static func consumePendingOpenSettings() -> Bool {
        guard let defaults else { return false }
        let pending = defaults.bool(forKey: pendingOpenSettingsKey)
        if pending {
            defaults.set(false, forKey: pendingOpenSettingsKey)
        }
        return pending
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private static func scaledBackgroundData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 600
        let size = image.size
        let maxSide = max(size.width, size.height)
        if maxSide <= maxDimension {
            return image.jpegData(compressionQuality: 0.82)
        }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaledImage.jpegData(compressionQuality: 0.82)
    }
}

enum PhotoWallRefreshMode: String, Codable {
    case daily
    case manual
}

enum PhotoWallBackgroundStyle: String, Codable, CaseIterable {
    case blackVelvet
    case whitePaper
    case warmPaper
    case newspaper

    static var allCases: [PhotoWallBackgroundStyle] {
        [.blackVelvet, .whitePaper, .warmPaper, .newspaper]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        switch rawValue {
        case PhotoWallBackgroundStyle.blackVelvet.rawValue:
            self = .blackVelvet
        case PhotoWallBackgroundStyle.warmPaper.rawValue:
            self = .warmPaper
        case "grayPaper":
            self = .whitePaper
        case "wood":
            self = .newspaper
        case PhotoWallBackgroundStyle.whitePaper.rawValue:
            self = .whitePaper
        case PhotoWallBackgroundStyle.newspaper.rawValue:
            self = .newspaper
        default:
            self = .blackVelvet
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PhotoWallSettings: Codable, Equatable {
    var mode: PhotoWallRefreshMode
    var manualAssetIdentifiers: [String]
    var pendingOneTimeRandom: Bool
    var lastDailyRefreshAt: Date?
    var backgroundStyle: PhotoWallBackgroundStyle
    var customBackgroundFileNameSquare: String?
    var customBackgroundFileNameWide: String?
    var customBackgroundFileName: String?

    init(
        mode: PhotoWallRefreshMode = .daily,
        manualAssetIdentifiers: [String] = [],
        pendingOneTimeRandom: Bool = false,
        lastDailyRefreshAt: Date? = nil,
        backgroundStyle: PhotoWallBackgroundStyle = .blackVelvet,
        customBackgroundFileNameSquare: String? = nil,
        customBackgroundFileNameWide: String? = nil,
        customBackgroundFileName: String? = nil
    ) {
        self.mode = mode
        self.manualAssetIdentifiers = manualAssetIdentifiers
        self.pendingOneTimeRandom = pendingOneTimeRandom
        self.lastDailyRefreshAt = lastDailyRefreshAt
        self.backgroundStyle = backgroundStyle
        self.customBackgroundFileNameSquare = customBackgroundFileNameSquare
        self.customBackgroundFileNameWide = customBackgroundFileNameWide
        self.customBackgroundFileName = customBackgroundFileName
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case manualAssetIdentifiers
        case pendingOneTimeRandom
        case lastDailyRefreshAt
        case backgroundStyle
        case customBackgroundFileNameSquare
        case customBackgroundFileNameWide
        case customBackgroundFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyFileName = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileName)
        mode = try container.decodeIfPresent(PhotoWallRefreshMode.self, forKey: .mode) ?? .daily
        manualAssetIdentifiers = try container.decodeIfPresent([String].self, forKey: .manualAssetIdentifiers) ?? []
        pendingOneTimeRandom = try container.decodeIfPresent(Bool.self, forKey: .pendingOneTimeRandom) ?? false
        lastDailyRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastDailyRefreshAt)
        backgroundStyle = try container.decodeIfPresent(PhotoWallBackgroundStyle.self, forKey: .backgroundStyle) ?? .blackVelvet
        customBackgroundFileNameSquare = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileNameSquare) ?? legacyFileName
        customBackgroundFileNameWide = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileNameWide) ?? legacyFileName
        customBackgroundFileName = legacyFileName
    }
}

@MainActor
final class PhotoWallSettingsStore: ObservableObject {
    @Published var current: PhotoWallSettings {
        didSet { WidgetPhotoStore.savePhotoWallSettings(current) }
    }

    init() {
        current = WidgetPhotoStore.loadPhotoWallSettings()
    }

    func reload() {
        current = WidgetPhotoStore.loadPhotoWallSettings()
    }
}
