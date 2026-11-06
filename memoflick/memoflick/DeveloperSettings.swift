//
//  DeveloperSettings.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import Foundation
import Combine
import SwiftUI

struct DeveloperSettings: Codable, Equatable {
    var theme: AppTheme
    var languageOverride: AppLanguage?
    var simulateLoggedIn: Bool
    var premiumOverride: PremiumOverride
    var simulatedDate: Date?

    init(
        theme: AppTheme = .system,
        languageOverride: AppLanguage? = nil,
        simulateLoggedIn: Bool = false,
        premiumOverride: PremiumOverride = .system,
        simulatedDate: Date? = nil
    ) {
        self.theme = theme
        self.languageOverride = languageOverride
        self.simulateLoggedIn = simulateLoggedIn
        self.premiumOverride = premiumOverride
        self.simulatedDate = simulatedDate
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
            languageOverride = try container.decodeIfPresent(AppLanguage.self, forKey: .languageOverride)
            simulateLoggedIn = try container.decodeIfPresent(Bool.self, forKey: .simulateLoggedIn) ?? false
            premiumOverride = try container.decodeIfPresent(PremiumOverride.self, forKey: .premiumOverride) ?? .system
            simulatedDate = try container.decodeIfPresent(Date.self, forKey: .simulatedDate)
            return
        }

        // 兼容旧版本存档
        if let legacyContainer = try? decoder.singleValueContainer(),
           (try? legacyContainer.decode([String: Double].self)) != nil {
            theme = .system
            languageOverride = nil
            simulateLoggedIn = false
            premiumOverride = .system
            simulatedDate = nil
            return
        }

        theme = .system
        languageOverride = nil
        simulateLoggedIn = false
        premiumOverride = .system
        simulatedDate = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encodeIfPresent(languageOverride, forKey: .languageOverride)
        try container.encode(simulateLoggedIn, forKey: .simulateLoggedIn)
        try container.encode(premiumOverride, forKey: .premiumOverride)
        try container.encodeIfPresent(simulatedDate, forKey: .simulatedDate)
    }

    private enum CodingKeys: String, CodingKey {
        case theme
        case languageOverride
        case simulateLoggedIn
        case premiumOverride
        case simulatedDate
    }
}

extension DeveloperSettings {
    /// Only include字段 that影响滑片逻辑, 暂无可调参数, 保持常量即可.
    var reviewTuningSignature: Int {
        var hasher = Hasher()
        hasher.combine(0)
        return hasher.finalize()
    }
}

private struct SimulatedTodayKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    var simulatedToday: Date? {
        get { self[SimulatedTodayKey.self] }
        set { self[SimulatedTodayKey.self] = newValue }
    }
}

extension Date {
    func applyingSimulatedDay(_ simulated: Date?) -> Date {
        guard let simulated else { return self }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: self)
        var target = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: simulated)) ?? simulated
        if let h = components.hour, let m = components.minute, let s = components.second, let n = components.nanosecond {
            target = calendar.date(bySettingHour: h, minute: m, second: s, of: target) ?? target
            target.addTimeInterval(Double(n) / 1_000_000_000)
        }
        return target
    }
}

enum PremiumOverride: String, Codable, CaseIterable, Equatable, Identifiable {
    case system
    case basic
    case premium

    var id: String { rawValue }

    func displayName(using localizer: AppLocalizer) -> String {
        switch self {
        case .system:
            return localizer.text(.developerPremiumFollowReal)
        case .basic:
            return localizer.text(.developerPremiumBasicName)
        case .premium:
            return localizer.text(.developerPremiumProName)
        }
    }
}

@MainActor
final class DeveloperSettingsStore: ObservableObject {
    @Published var current: DeveloperSettings {
        didSet { persist() }
    }

    private let defaultsKey = "developer_settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(DeveloperSettings.self, from: data) {
            current = decoded
        } else {
            current = DeveloperSettings()
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(current) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
