//
//  PhotoAnalyzer.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import Foundation
import UIKit
import Photos

struct PhotoAnalyzer: @unchecked Sendable {
    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 512, height: 512)

    func prepareForScan(assets: [PHAsset], allowNetworkAccess: Bool) {
        guard !assets.isEmpty else { return }
        let options = cachingOptions(allowNetworkAccess: allowNetworkAccess)
        imageManager.startCachingImages(
            for: assets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func finishScan(assets: [PHAsset], allowNetworkAccess: Bool) {
        guard !assets.isEmpty else { return }
        let options = cachingOptions(allowNetworkAccess: allowNetworkAccess)
        imageManager.stopCachingImages(
            for: assets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func analyze(asset: PHAsset, allowNetworkAccess: Bool = true) async -> PhotoMetrics? {
        guard let image = await loadThumbnail(for: asset, allowNetworkAccess: allowNetworkAccess) else { return nil }
        return PhotoMetrics(blurMetric: blurMetric(for: image), averageBrightness: brightnessMetric(for: image))
    }

    func analyze(image: UIImage) -> PhotoMetrics? {
        PhotoMetrics(blurMetric: blurMetric(for: image), averageBrightness: brightnessMetric(for: image))
    }

    func quality(for metrics: PhotoMetrics) -> PhotoQuality {
        PhotoQuality(
            blurScore: 0.5,
            exposureScore: 0.5,
            qualityScore: 0.5,
            tags: []
        )
    }
}

private extension PhotoAnalyzer {
    func cachingOptions(allowNetworkAccess: Bool) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = allowNetworkAccess
        return options
    }

    func loadThumbnail(for asset: PHAsset, allowNetworkAccess: Bool) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = allowNetworkAccess

            imageManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func blurMetric(for image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let targetWidth = 64
        let aspect = Double(cgImage.height) / Double(cgImage.width)
        let targetHeight = max(8, Int(Double(targetWidth) * aspect))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: 0
        ) else {
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let data = context.data else { return 0 }

        let pixelCount = targetWidth * targetHeight
        let pointer = data.bindMemory(to: UInt8.self, capacity: pixelCount)

        var sum: Double = 0
        for index in 0..<pixelCount {
            sum += Double(pointer[index])
        }
        let mean = sum / Double(pixelCount)

        var variance: Double = 0
        for index in 0..<pixelCount {
            let diff = Double(pointer[index]) - mean
            variance += diff * diff
        }
        variance /= Double(pixelCount)

        return min(max(variance / 2000.0, 0), 1)
    }

    func brightnessMetric(for image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        let targetSize = CGSize(width: 32, height: 32)

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(targetSize.width),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: 0
        ) else {
            return 0.5
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        guard let data = context.data else { return 0.5 }

        let pixelCount = Int(targetSize.width * targetSize.height)
        let pointer = data.bindMemory(to: UInt8.self, capacity: pixelCount)

        var sum: Double = 0
        for index in 0..<pixelCount {
            sum += Double(pointer[index])
        }

        let average = sum / Double(pixelCount) / 255.0
        return min(max(average, 0), 1)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
