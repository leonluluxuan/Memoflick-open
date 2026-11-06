//
//  PhotoModels.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import Foundation
import Photos
import UIKit

enum PhotoProcessStatus: Int, Codable {
    case pending = 0
    case kept = 1
    case trashed = 2
}

struct PhotoMetrics: Codable {
    var blurMetric: Double
    var averageBrightness: Double

    enum CodingKeys: String, CodingKey {
        case blurMetric
        case averageBrightness
    }

    init(blurMetric: Double = 0, averageBrightness: Double = 0) {
        self.blurMetric = blurMetric
        self.averageBrightness = averageBrightness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blurMetric = try container.decodeIfPresent(Double.self, forKey: .blurMetric) ?? 0
        averageBrightness = try container.decodeIfPresent(Double.self, forKey: .averageBrightness) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blurMetric, forKey: .blurMetric)
        try container.encode(averageBrightness, forKey: .averageBrightness)
    }
}

struct PhotoMeta: Identifiable, Codable {
    let id: String
    var metrics: PhotoMetrics
    var status: PhotoProcessStatus
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var caption: String?
    var categoryName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case metrics
        case status
        case createdAt
        case updatedAt
        case isFavorite
        case caption
        case categoryName
    }

    init(
        id: String,
        metrics: PhotoMetrics,
        status: PhotoProcessStatus,
        createdAt: Date,
        updatedAt: Date,
        isFavorite: Bool = false,
        caption: String? = nil,
        categoryName: String? = nil
    ) {
        self.id = id
        self.metrics = metrics
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.caption = caption
        self.categoryName = categoryName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        metrics = try container.decode(PhotoMetrics.self, forKey: .metrics)
        status = try container.decode(PhotoProcessStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
    }
}

struct PhotoQuality {
    var blurScore: Double
    var exposureScore: Double
    var qualityScore: Double
    var tags: [String]
}

struct PhotoReviewItem: Identifiable {
    enum Source {
        case asset(PHAsset)
        case test(TestImage)
    }

    struct TestImage {
        let image: UIImage
        let creationDate: Date
        let pixelWidth: Int
        let pixelHeight: Int
    }

    let source: Source
    var meta: PhotoMeta
    var quality: PhotoQuality

    var id: String { meta.id }

    var asset: PHAsset? {
        if case let .asset(asset) = source {
            return asset
        }
        return nil
    }

    var testImage: TestImage? {
        if case let .test(testImage) = source {
            return testImage
        }
        return nil
    }

    var pixelWidth: Int {
        switch source {
        case let .asset(asset):
            return asset.pixelWidth
        case let .test(testImage):
            return testImage.pixelWidth
        }
    }

    var pixelHeight: Int {
        switch source {
        case let .asset(asset):
            return asset.pixelHeight
        case let .test(testImage):
            return testImage.pixelHeight
        }
    }

    var creationDate: Date? {
        switch source {
        case let .asset(asset):
            return asset.creationDate
        case let .test(testImage):
            return testImage.creationDate
        }
    }

    var isTestItem: Bool {
        if case .test = source {
            return true
        }
        return false
    }

    var displayDate: String {
        guard let date = creationDate else { return Localization.text(.mediaUnknownTimestamp) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

extension PhotoReviewItem {
    init(asset: PHAsset, meta: PhotoMeta, quality: PhotoQuality) {
        self.source = .asset(asset)
        self.meta = meta
        self.quality = quality
    }

    init(testImage: TestImage, meta: PhotoMeta, quality: PhotoQuality) {
        self.source = .test(testImage)
        self.meta = meta
        self.quality = quality
    }
}

extension PhotoReviewItem: @unchecked Sendable {}
extension PhotoReviewItem.TestImage: @unchecked Sendable {}
extension PhotoReviewItem.Source: @unchecked Sendable {}
extension PHAsset: @unchecked Sendable {}
