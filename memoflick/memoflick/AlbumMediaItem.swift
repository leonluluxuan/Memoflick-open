//
//  AlbumMediaItem.swift
//  memoflick
//
//  Created by Codex on 2025/12/03.
//

import Foundation
import Photos
import UIKit

enum AlbumMediaType {
    case photo
    case video
}

struct AlbumMediaItem: Identifiable {
    let id: String
    let mediaType: AlbumMediaType
    let status: PhotoProcessStatus
    let updatedAt: Date
    let isFavorite: Bool
    let categoryName: String?
    let caption: String?
    let asset: PHAsset?
    let testImage: PhotoReviewItem.TestImage?
    let durationLabel: String?
    let photoItem: PhotoReviewItem?
    let videoItem: VideoReviewItem?
    let compressedSizeBytes: Int64?

    var isTrash: Bool { status == .trashed }

    var displayDate: String {
        if let photoItem {
            return photoItem.displayDate
        }
        if let videoItem {
            return videoItem.displayDate
        }
        if let date = asset?.creationDate {
            return AlbumMediaItem.dateFormatter.string(from: date)
        }
        return ""
    }

    var compressedSizeLabel: String? {
        guard let compressedSizeBytes else { return nil }
        return AlbumMediaItem.formatBytes(compressedSizeBytes)
    }

    /// Action timestamp (keep/delete/etc.) used for grouping.
    var actionDate: Date { updatedAt }

    /// Prefer the underlying asset/test creation date, fall back to last update.
    var creationDate: Date? {
        if let asset {
            return asset.creationDate
        }
        if let photoItem {
            return photoItem.creationDate
        }
        if let videoItem {
            return videoItem.creationDate
        }
        return nil
    }
}

extension AlbumMediaItem {
    init(photoItem: PhotoReviewItem) {
        self.id = photoItem.id
        self.mediaType = .photo
        self.status = photoItem.meta.status
        self.updatedAt = photoItem.meta.updatedAt
        self.isFavorite = photoItem.meta.isFavorite
        self.categoryName = photoItem.meta.categoryName
        self.caption = photoItem.meta.caption
        self.asset = photoItem.asset
        self.testImage = photoItem.testImage
        self.durationLabel = nil
        self.photoItem = photoItem
        self.videoItem = nil
        self.compressedSizeBytes = nil
    }

    init(videoItem: VideoReviewItem) {
        self.id = videoItem.id
        self.mediaType = .video
        self.status = videoItem.meta.status
        self.updatedAt = videoItem.meta.updatedAt
        self.isFavorite = videoItem.meta.isFavorite
        self.categoryName = videoItem.meta.categoryName
        self.caption = videoItem.meta.caption
        self.asset = videoItem.asset
        self.testImage = nil
        self.durationLabel = videoItem.durationLabel
        self.photoItem = nil
        self.videoItem = videoItem
        self.compressedSizeBytes = nil
    }

    init(asset: PHAsset, compressedSizeBytes: Int64?) {
        self.id = asset.localIdentifier
        if asset.mediaType == .video {
            self.mediaType = .video
        } else {
            self.mediaType = .photo
        }
        self.status = .kept
        self.updatedAt = asset.creationDate ?? Date()
        self.isFavorite = false
        self.categoryName = nil
        self.caption = nil
        self.asset = asset
        self.testImage = nil
        if asset.mediaType == .video {
            self.durationLabel = AlbumMediaItem.formatDuration(asset.duration)
        } else {
            self.durationLabel = nil
        }
        self.photoItem = nil
        self.videoItem = nil
        self.compressedSizeBytes = compressedSizeBytes
    }

    init(testImage: UIImage, date: Date, id: String = UUID().uuidString, status: PhotoProcessStatus = .trashed, compressedSizeBytes: Int64? = nil) {
        self.id = id
        self.mediaType = .photo
        self.status = status
        self.updatedAt = date
        self.isFavorite = false
        self.categoryName = nil
        self.caption = nil
        self.asset = nil
        self.testImage = PhotoReviewItem.TestImage(
            image: testImage,
            creationDate: date,
            pixelWidth: Int(testImage.size.width),
            pixelHeight: Int(testImage.size.height)
        )
        self.durationLabel = nil
        self.photoItem = nil
        self.videoItem = nil
        self.compressedSizeBytes = compressedSizeBytes
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb >= 1 {
            return String(format: "%.2f MB", mb)
        }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()

    private static func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "00:00" }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
