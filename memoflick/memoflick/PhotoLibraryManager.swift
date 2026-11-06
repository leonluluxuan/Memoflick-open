//
//  PhotoLibraryManager.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import Foundation
import Photos

final class PhotoLibraryManager {
    func currentAuthorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func fetchPhotoAssets(limit: Int? = nil, sortAscending: Bool = true) -> [PHAsset] {
        fetchAssets(of: .image, limit: limit, sortAscending: sortAscending)
    }

    func fetchPhotoAssetsAsync(limit: Int? = nil, sortAscending: Bool = true) async -> [PHAsset] {
        await fetchAssetsAsync(of: .image, limit: limit, sortAscending: sortAscending)
    }

    func fetchVideoAssets(limit: Int? = nil, sortAscending: Bool = true) -> [PHAsset] {
        fetchAssets(of: .video, limit: limit, sortAscending: sortAscending)
    }

    func fetchVideoAssetsAsync(limit: Int? = nil, sortAscending: Bool = true) async -> [PHAsset] {
        await fetchAssetsAsync(of: .video, limit: limit, sortAscending: sortAscending)
    }
}

private extension PhotoLibraryManager {
    func fetchAssetsAsync(
        of mediaType: PHAssetMediaType,
        limit: Int? = nil,
        sortAscending: Bool = true
    ) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let assets = self.fetchAssets(of: mediaType, limit: limit, sortAscending: sortAscending)
                continuation.resume(returning: assets)
            }
        }
    }

    func fetchAssets(
        of mediaType: PHAssetMediaType,
        limit: Int? = nil,
        sortAscending: Bool = true
    ) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortAscending)]
        if let limit {
            options.fetchLimit = limit
        }
        let results = PHAsset.fetchAssets(with: mediaType, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(results.count)
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
}
