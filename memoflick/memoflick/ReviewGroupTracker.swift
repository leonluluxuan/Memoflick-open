//
//  ReviewGroupTracker.swift
//  memoflick
//
//  Created by Codex on 2025/12/30.
//

import Foundation

struct GroupUsageSnapshot {
    let consumedInCurrentGroup: Int
    let groupsUsedToday: Int
    let groupSize: Int
    let dailyLimit: Int
    let lastResetDate: Date

    var isGateActive: Bool {
        consumedInCurrentGroup >= groupSize
    }

    var hasRemainingQuota: Bool {
        groupsUsedToday < dailyLimit
    }

    var groupsRemaining: Int {
        max(dailyLimit - groupsUsedToday, 0)
    }

    var currentGroupIndex: Int {
        min(groupsUsedToday + 1, dailyLimit)
    }
}

final class ReviewGroupTracker {
    struct Config {
        let groupSize: Int
        let dailyLimit: Int
        let storageKey: String
    }

    private struct StoredState: Codable {
        var groupsUsedToday: Int
        var consumedInCurrentGroup: Int
        var lastResetDate: Date
    }

    private let config: Config
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var state: StoredState

    init(
        config: Config,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.config = config
        self.defaults = defaults
        self.calendar = calendar
        let now = Date()
        state = Self.loadState(
            for: config.storageKey,
            defaults: defaults
        ) ?? StoredState(
            groupsUsedToday: 0,
            consumedInCurrentGroup: 0,
            lastResetDate: now
        )
        resetIfNeeded(date: now)
        persist()
    }

    func currentStatus() -> GroupUsageSnapshot {
        resetIfNeeded()
        return snapshot(from: state)
    }

    func registerConsumption() -> GroupUsageSnapshot {
        resetIfNeeded()
        guard state.consumedInCurrentGroup < config.groupSize else {
            return snapshot(from: state)
        }

        state.consumedInCurrentGroup += 1
        if state.consumedInCurrentGroup >= config.groupSize {
            state.groupsUsedToday += 1
            state.consumedInCurrentGroup = min(state.consumedInCurrentGroup, config.groupSize)
        }
        persist()
        return snapshot(from: state)
    }

    func undoConsumption() -> GroupUsageSnapshot {
        resetIfNeeded()

        if state.consumedInCurrentGroup > 0 {
            let wasGateActive = state.consumedInCurrentGroup >= config.groupSize
            state.consumedInCurrentGroup -= 1
            if wasGateActive && state.groupsUsedToday > 0 {
                state.groupsUsedToday -= 1
            }
        } else if state.groupsUsedToday > 0 {
            state.groupsUsedToday -= 1
            state.consumedInCurrentGroup = max(config.groupSize - 1, 0)
        }

        persist()
        return snapshot(from: state)
    }

    func startNextGroupIfAvailable() -> GroupUsageSnapshot {
        resetIfNeeded()
        guard state.groupsUsedToday < config.dailyLimit else {
            return snapshot(from: state)
        }
        state.consumedInCurrentGroup = 0
        persist()
        return snapshot(from: state)
    }

    func startNextGroupIgnoringLimit() -> GroupUsageSnapshot {
        resetIfNeeded()
        state.consumedInCurrentGroup = 0
        persist()
        return snapshot(from: state)
    }
}

private extension ReviewGroupTracker {
    private func snapshot(from state: StoredState) -> GroupUsageSnapshot {
        GroupUsageSnapshot(
            consumedInCurrentGroup: min(state.consumedInCurrentGroup, config.groupSize),
            groupsUsedToday: state.groupsUsedToday,
            groupSize: config.groupSize,
            dailyLimit: config.dailyLimit,
            lastResetDate: state.lastResetDate
        )
    }

    func resetIfNeeded(date: Date = Date()) {
        if !calendar.isDate(state.lastResetDate, inSameDayAs: date) {
            state = StoredState(
                groupsUsedToday: 0,
                consumedInCurrentGroup: 0,
                lastResetDate: date
            )
        } else {
            state.lastResetDate = date
        }
        persist()
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: config.storageKey)
    }

    private static func loadState(for key: String, defaults: UserDefaults) -> StoredState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }
}
