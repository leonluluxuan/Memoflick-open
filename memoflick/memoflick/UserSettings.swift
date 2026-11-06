//
//  UserSettings.swift
//  memoflick
//
//  Created by Codex on 2025/11/26.
//

import Foundation
import Combine

struct YearMonth: Codable, Hashable, Comparable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = min(max(month, 1), 12)
    }

    init?(date: Date) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        self.init(year: year, month: month)
    }

    var key: String { "\(year)-\(String(format: "%02d", month))" }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        if lhs.year == rhs.year {
            return lhs.month < rhs.month
        }
        return lhs.year < rhs.year
    }
}

enum MediaTimeFilter: Codable, Equatable {
    case all
    case months([YearMonth])

    var months: [YearMonth] {
        switch self {
        case .all:
            return []
        case let .months(values):
            return values
        }
    }

    func contains(_ yearMonth: YearMonth) -> Bool {
        switch self {
        case .all:
            return true
        case let .months(values):
            return values.contains(yearMonth)
        }
    }
}

struct UserSettings: Codable, Equatable {
    var photoTimeFilter: MediaTimeFilter
    var videoTimeFilter: MediaTimeFilter
    var hasSeenPhotoTutorial: Bool

    init(
        photoTimeFilter: MediaTimeFilter = .all,
        videoTimeFilter: MediaTimeFilter = .all,
        hasSeenPhotoTutorial: Bool = false
    ) {
        self.photoTimeFilter = photoTimeFilter
        self.videoTimeFilter = videoTimeFilter
        self.hasSeenPhotoTutorial = hasSeenPhotoTutorial
    }

    enum CodingKeys: String, CodingKey {
        case photoTimeFilter
        case videoTimeFilter
        case hasSeenPhotoTutorial
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        photoTimeFilter = try container.decodeIfPresent(MediaTimeFilter.self, forKey: .photoTimeFilter) ?? .all
        videoTimeFilter = try container.decodeIfPresent(MediaTimeFilter.self, forKey: .videoTimeFilter) ?? .all
        hasSeenPhotoTutorial = try container.decodeIfPresent(Bool.self, forKey: .hasSeenPhotoTutorial) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photoTimeFilter, forKey: .photoTimeFilter)
        try container.encode(videoTimeFilter, forKey: .videoTimeFilter)
        try container.encode(hasSeenPhotoTutorial, forKey: .hasSeenPhotoTutorial)
    }
}

@MainActor
final class UserSettingsStore: ObservableObject {
    @Published var current: UserSettings {
        didSet { persist() }
    }

    private let defaultsKey = "user_settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            current = decoded
        } else {
            let defaults = UserSettings()
            current = defaults
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
