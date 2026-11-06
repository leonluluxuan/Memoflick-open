//
//  NetworkMonitor.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "memoflick.network.monitor")
    private let lock = NSLock()
    private var isCellular = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(with: path)
        }
        monitor.start(queue: queue)
    }

    var allowsICloudDownload: Bool {
        lock.lock()
        let allowed = !isCellular
        lock.unlock()
        return allowed
    }

    private func update(with path: NWPath) {
        lock.lock()
        isCellular = path.usesInterfaceType(.cellular)
        lock.unlock()
    }
}
