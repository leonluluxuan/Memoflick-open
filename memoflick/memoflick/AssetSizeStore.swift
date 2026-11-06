import Foundation
import Photos
import Combine

@MainActor
final class AssetSizeStore: ObservableObject {
    static let shared = AssetSizeStore()

    @Published private(set) var cachedSizes: [String: Int64]

    private var inFlight: [String: Task<Int64?, Never>] = [:]
    private let defaultsKey = "asset_size_cache_v1"
    private let calculator = AssetSizeCalculator()
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Int64].self, from: data) {
            cachedSizes = decoded
        } else {
            cachedSizes = [:]
        }
    }

    func cachedSize(for assetID: String) -> Int64? {
        cachedSizes[assetID]
    }

    func cachedSize(for asset: PHAsset) -> Int64? {
        cachedSizes[asset.localIdentifier]
    }

    func requestSize(for asset: PHAsset, allowNetworkAccess: Bool = true) async -> Int64? {
        await requestSize(for: asset.localIdentifier, allowNetworkAccess: allowNetworkAccess)
    }

    func requestSize(for assetID: String, allowNetworkAccess: Bool = true) async -> Int64? {
        if let size = cachedSizes[assetID] {
            return size
        }

        if let task = inFlight[assetID] {
            return await task.value
        }

        let task = Task.detached(priority: .utility) { [calculator] in
            await calculator.exactSize(for: assetID, allowNetworkAccess: allowNetworkAccess)
        }
        inFlight[assetID] = task

        let size = await task.value
        inFlight[assetID] = nil

        if let size, size > 0 {
            cachedSizes[assetID] = size
            persist()
        }

        return size
    }

    func requestSizeIfNeeded(
        for assetID: String,
        allowNetworkAccess: Bool = true,
        onResolved: @escaping (Int64?) -> Void
    ) {
        if let size = cachedSizes[assetID] {
            onResolved(size)
            return
        }

        Task {
            let size = await requestSize(for: assetID, allowNetworkAccess: allowNetworkAccess)
            await MainActor.run {
                onResolved(size)
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cachedSizes) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}

actor AssetSizeCalculator {
    func exactSize(for assetID: String, allowNetworkAccess: Bool) async -> Int64? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = Self.preferredResource(for: asset, resources: resources) else { return nil }
        return await requestSize(for: resource, allowNetworkAccess: allowNetworkAccess)
    }

    private static func preferredResource(for asset: PHAsset, resources: [PHAssetResource]) -> PHAssetResource? {
        let preferredTypes: [PHAssetResourceType]
        switch asset.mediaType {
        case .image:
            preferredTypes = [.fullSizePhoto, .photo]
        case .video:
            preferredTypes = [.fullSizeVideo, .video]
        default:
            preferredTypes = []
        }

        for type in preferredTypes {
            if let resource = resources.first(where: { $0.type == type }) {
                return resource
            }
        }
        return resources.first
    }

    private func requestSize(
        for resource: PHAssetResource,
        allowNetworkAccess: Bool
    ) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = allowNetworkAccess

            var total: Int64 = 0
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    total += Int64(data.count)
                },
                completionHandler: { error in
                    if error != nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: total)
                    }
                }
            )
        }
    }
}
