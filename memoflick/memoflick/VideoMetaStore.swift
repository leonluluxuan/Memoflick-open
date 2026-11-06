//
//  VideoMetaStore.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import Foundation

actor VideoMetaStore {
    private var items: [String: VideoMeta] = [:]
    private let url: URL
    private var dirtyIdentifiers: Set<String> = []
    private let batchSize = 40
    private var isLoaded = false
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    init(fileName: String = "video_meta.json") {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        url = directory.appendingPathComponent(fileName)
        loadFromDisk()
    }

    func meta(for identifier: String) -> VideoMeta? {
        items[identifier]
    }

    func allMeta() -> [VideoMeta] {
        Array(items.values)
    }

    func count() -> Int {
        items.count
    }

    func waitUntilLoaded() async {
        if isLoaded { return }
        await withCheckedContinuation { continuation in
            loadWaiters.append(continuation)
        }
    }

    func upsert(_ meta: VideoMeta) async {
        items[meta.id] = meta
        dirtyIdentifiers.insert(meta.id)
        await saveIfNeeded()
    }

    func remove(for identifier: String) async {
        items.removeValue(forKey: identifier)
        dirtyIdentifiers.insert(identifier)
        await saveIfNeeded(force: true)
    }

    func flush() async {
        await saveToDisk()
    }

    nonisolated private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Task { await finishLoading(decoded: nil) }
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: VideoMeta].self, from: data)
            Task { [decoded] in
                await finishLoading(decoded: decoded)
            }
        } catch {
            print("Failed to load VideoMeta from disk:", error)
            Task { await finishLoading(decoded: nil) }
        }
    }

    private func finishLoading(decoded: [String: VideoMeta]?) {
        if let decoded {
            items = decoded
        }
        isLoaded = true
        let waiters = loadWaiters
        loadWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func saveIfNeeded(force: Bool = false) async {
        guard force || dirtyIdentifiers.count >= batchSize else { return }
        await saveToDisk()
    }

    private func saveToDisk() async {
        guard !dirtyIdentifiers.isEmpty else { return }
        let dirtySnapshot = dirtyIdentifiers
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: [.atomic])
            dirtyIdentifiers.subtract(dirtySnapshot)
        } catch {
            dirtyIdentifiers.formUnion(dirtySnapshot)
            print("Failed to save VideoMeta to disk:", error)
        }
    }
}
