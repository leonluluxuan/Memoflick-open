import Foundation

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

    static func saveSnapshot(_ snapshot: WidgetPhotoSnapshot) {
        guard
            let defaults,
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func thumbnailData(for candidate: WidgetPhotoCandidate) -> Data? {
        if let data = candidate.thumbnailData, !data.isEmpty {
            return data
        }
        guard let fileName = candidate.thumbnailFileName else { return nil }
        return thumbnailData(for: fileName)
    }

    static func thumbnailData(for fileName: String) -> Data? {
        guard let url = thumbnailURL(for: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func thumbnailURL(for fileName: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = containerURL.appendingPathComponent(thumbnailDirectoryName, isDirectory: true)
        return directory.appendingPathComponent(fileName)
    }

    static func photoWallBackgroundData(for fileName: String) -> Data? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = containerURL.appendingPathComponent(backgroundDirectoryName, isDirectory: true)
        let url = directory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    static func photoWallBackgroundData() -> Data? {
        defaults?.data(forKey: photoWallBackgroundDataKey)
    }

    static func setPendingOpenSettings(_ pending: Bool) {
        defaults?.set(pending, forKey: pendingOpenSettingsKey)
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

    static func bumpRefreshToken() -> String {
        var snapshot = loadSnapshot()
        snapshot.refreshToken = UUID().uuidString
        snapshot.updatedAt = Date()
        saveSnapshot(snapshot)
        return snapshot.refreshToken
    }
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
    var backgroundStyle: PhotoWallBackgroundStyle
    var customBackgroundFileNameSquare: String?
    var customBackgroundFileNameWide: String?
    var customBackgroundFileName: String?

    init(
        backgroundStyle: PhotoWallBackgroundStyle = .blackVelvet,
        customBackgroundFileNameSquare: String? = nil,
        customBackgroundFileNameWide: String? = nil,
        customBackgroundFileName: String? = nil
    ) {
        self.backgroundStyle = backgroundStyle
        self.customBackgroundFileNameSquare = customBackgroundFileNameSquare
        self.customBackgroundFileNameWide = customBackgroundFileNameWide
        self.customBackgroundFileName = customBackgroundFileName
    }

    enum CodingKeys: String, CodingKey {
        case backgroundStyle
        case customBackgroundFileNameSquare
        case customBackgroundFileNameWide
        case customBackgroundFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyFileName = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileName)
        backgroundStyle = try container.decodeIfPresent(PhotoWallBackgroundStyle.self, forKey: .backgroundStyle) ?? .blackVelvet
        customBackgroundFileNameSquare = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileNameSquare) ?? legacyFileName
        customBackgroundFileNameWide = try container.decodeIfPresent(String.self, forKey: .customBackgroundFileNameWide) ?? legacyFileName
        customBackgroundFileName = legacyFileName
    }
}
