//
//  VideoAssetLoader.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import AVFoundation
import Photos

struct VideoAssetLoader {
    private let imageManager = PHCachingImageManager()
    private let options: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .original
        options.isNetworkAccessAllowed = true
        return options
    }()

    func playerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await withCheckedContinuation { continuation in
            imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                continuation.resume(returning: playerItem)
            }
        }
    }
}
