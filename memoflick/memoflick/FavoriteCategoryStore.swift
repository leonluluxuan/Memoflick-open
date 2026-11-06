//
//  FavoriteCategoryStore.swift
//  memoflick
//
//  Created by Codex on 2025/12/10.
//

import Foundation
import Combine

final class FavoriteCategoryStore: ObservableObject {
    static let defaultCategoryName = "未命名分类"
    private static let legacyDefaultNames: Set<String> = ["未命名分类", "Untitled Category"]

    @Published private(set) var categories: [String]

    private let storageKey = "favorite_categories"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let prepared = FavoriteCategoryStore.prepareCategories(from: userDefaults.stringArray(forKey: storageKey))
        _categories = Published(initialValue: prepared)
        userDefaults.set(prepared, forKey: storageKey)
    }

    var availableCategories: [String] {
        categories.isEmpty ? [Self.defaultCategoryName] : categories
    }

    func addCategoryIfNeeded(_ name: String) {
        let normalized = normalizeCategoryName(name)
        guard !categories.contains(normalized) else { return }
        categories.append(normalized)
        save()
    }

    func recordSelection(of name: String) {
        let normalized = normalizeCategoryName(name)
        if let index = categories.firstIndex(of: normalized) {
            categories.remove(at: index)
        } else {
            categories.append(normalized)
        }
        categories.insert(normalized, at: 0)
        save()
    }

    func ensureCategoryExists(_ name: String) {
        let normalized = normalizeCategoryName(name)
        if !categories.contains(normalized) {
            categories.append(normalized)
            save()
        }
    }

    func removeCategoryIfNeeded(_ name: String) {
        let normalized = normalizeCategoryName(name)
        guard normalized != Self.defaultCategoryName else { return }
        categories.removeAll { $0 == normalized }
        save()
    }

    func renameCategory(from oldName: String, to newName: String) {
        let normalizedOld = normalizeCategoryName(oldName)
        let normalizedNew = normalizeCategoryName(newName)
        guard normalizedOld != normalizedNew else { return }
        guard normalizedOld != Self.defaultCategoryName else { return }
        categories = categories.map { $0 == normalizedOld ? normalizedNew : $0 }
        var seen = Set<String>()
        categories = categories.filter { name in
            if seen.contains(name) { return false }
            seen.insert(name)
            return true
        }
        save()
    }

    func normalizeCategoryName(_ name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.defaultCategoryName }
        return Self.canonicalDefaultName(for: trimmed)
    }

    private func save() {
        userDefaults.set(categories, forKey: storageKey)
    }

    private static func prepareCategories(from raw: [String]?) -> [String] {
        var prepared: [String] = []
        let source = raw ?? []
        for name in source {
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let canonical = canonicalDefaultName(for: normalized)
            if !prepared.contains(canonical) {
                prepared.append(canonical)
            }
        }
        if !prepared.contains(Self.defaultCategoryName) {
            prepared.insert(Self.defaultCategoryName, at: 0)
        }
        return prepared
    }

    private static func canonicalDefaultName(for name: String) -> String {
        if legacyDefaultNames.contains(name) {
            return Self.defaultCategoryName
        }
        return name
    }
}

extension FavoriteCategoryStore {
    static func isDefaultCategoryName(_ name: String) -> Bool {
        legacyDefaultNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func localizedDefaultName(for language: AppLanguage) -> String {
        Localization.text(.favoriteDefaultCategory, language: language)
    }

    static func displayName(for rawName: String?, language: AppLanguage) -> String {
        let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || isDefaultCategoryName(trimmed) {
            return localizedDefaultName(for: language)
        }
        return trimmed
    }
}
