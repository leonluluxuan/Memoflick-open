//
//  VideoModels.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import Foundation
import CoreGraphics
import Photos

struct VideoMeta: Identifiable, Codable {
    let id: String
    var status: PhotoProcessStatus
    var createdAt: Date
    var updatedAt: Date
    var duration: Double
    var isFavorite: Bool
    var caption: String?
    var categoryName: String?

    init(
        id: String,
        status: PhotoProcessStatus,
        createdAt: Date,
        updatedAt: Date,
        duration: Double,
        isFavorite: Bool = false,
        caption: String? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.duration = duration
        self.isFavorite = isFavorite
        self.caption = caption
        self.categoryName = categoryName
    }
}

struct VideoReviewItem: Identifiable {
    let asset: PHAsset
    var meta: VideoMeta

    var id: String { meta.id }
    var duration: TimeInterval { asset.duration }
    var creationDate: Date? { asset.creationDate }
    var aspectRatio: CGFloat {
        let width = max(CGFloat(asset.pixelWidth), 1)
        let height = max(CGFloat(asset.pixelHeight), 1)
        return height / width
    }

    var durationLabel: String {
        guard duration > 0 else { return "00:00" }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var displayDate: String {
        guard let creationDate else { return Localization.text(.mediaUnknownTimestamp) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: creationDate)
    }
}
