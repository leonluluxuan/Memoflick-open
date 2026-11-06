//
//  LanguageCoordinator.swift
//  memoflick
//
//  Created by Codex on 2025/12/25.
//

import Foundation
import Combine

final class LanguageCoordinator: ObservableObject {
    @Published private(set) var detectedLanguage: AppLanguage

    private struct DetectionCache: Codable {
        let language: AppLanguage
        let timestamp: Date
    }

    private let defaults: UserDefaults
    private let cacheKey = "language_detection_cache_v1"
    private var detectionCache: DetectionCache?
    private let cacheValidity: TimeInterval = 60 * 30 // 30 minutes

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.detectionCache = Self.loadCache(from: defaults, key: cacheKey)
        self.detectedLanguage = detectionCache?.language ?? AppLanguage.deviceDefault
    }

    func refreshLanguage(force: Bool = false) async {
        if let cached = await cachedLanguageIfValid(), !force {
            await updateLanguage(cached)
            return
        }

        let language = systemPreferredLanguage()
        await updateLanguage(language)
        let cache = DetectionCache(language: language, timestamp: Date())
        await MainActor.run {
            self.detectionCache = cache
            self.persist(cache)
        }
    }

    private func cachedLanguageIfValid() async -> AppLanguage? {
        await MainActor.run {
            guard let cache = detectionCache else { return nil }
            return Date().timeIntervalSince(cache.timestamp) < cacheValidity ? cache.language : nil
        }
    }

    private func updateLanguage(_ language: AppLanguage) async {
        await MainActor.run {
            detectedLanguage = language
        }
    }

    private func systemPreferredLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? Locale.current.identifier.lowercased()
        let region = Locale.current.region?.identifier.lowercased() ?? ""
        if preferred.contains("zh") || region.contains("cn") || region.contains("hk") || region.contains("mo") {
            return .simplifiedChinese
        }
        return .english
    }

    private func persist(_ cache: DetectionCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: cacheKey)
    }

    private static func loadCache(from defaults: UserDefaults, key: String) -> DetectionCache? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DetectionCache.self, from: data)
    }
}
