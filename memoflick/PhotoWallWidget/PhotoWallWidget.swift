import WidgetKit
import SwiftUI
import AppIntents
import UIKit

struct PhotoItem: Identifiable, Hashable {
    let id: String
    let assetIdentifier: String
    let aspectRatio: CGFloat
    let imageData: Data?

    init(assetIdentifier: String, aspectRatio: CGFloat, imageData: Data? = nil) {
        if assetIdentifier.isEmpty {
            self.id = UUID().uuidString
        } else {
            self.id = assetIdentifier
        }
        self.assetIdentifier = assetIdentifier
        self.aspectRatio = aspectRatio
        self.imageData = imageData
    }
}

struct PhotoEntry: TimelineEntry {
    let date: Date
    let photos: [PhotoItem]
    let layoutSeed: UInt64
    let backgroundStyle: PhotoWallBackgroundStyle
    let customBackgroundFileName: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(
            date: Date(),
            photos: samplePhotos(count: photoCount(for: context.family)),
            layoutSeed: 0,
            backgroundStyle: .blackVelvet,
            customBackgroundFileName: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoEntry) -> Void) {
        completion(
            PhotoEntry(
                date: Date(),
                photos: samplePhotos(count: photoCount(for: context.family)),
                layoutSeed: 0,
                backgroundStyle: .blackVelvet,
                customBackgroundFileName: nil
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetPhotoStore.loadSnapshot()
        let token = snapshot.refreshToken.isEmpty ? WidgetPhotoStore.refreshToken() : snapshot.refreshToken
        let seed = dailySeed(for: now, refreshToken: token)
        let targetCount = photoCount(for: context.family)

        let candidates = buildCandidatePool(from: snapshot)
        let selectedCandidates = pickCandidates(candidates, count: targetCount, seed: seed)
        let photos: [PhotoItem]

        if selectedCandidates.isEmpty {
            photos = samplePhotos(count: targetCount)
        } else {
            var picked: [PhotoItem] = []
            picked.reserveCapacity(targetCount)
            for candidate in selectedCandidates {
                let imageData = WidgetPhotoStore.thumbnailData(for: candidate)
                let ratio = normalizedAspectRatio(for: candidate.aspectRatio)
                picked.append(
                    PhotoItem(
                        assetIdentifier: candidate.assetIdentifier,
                        aspectRatio: ratio,
                        imageData: imageData
                    )
                )
            }
            if picked.count < targetCount {
                picked.append(contentsOf: samplePhotos(count: targetCount - picked.count))
            }
            photos = picked
        }

        let settings = WidgetPhotoStore.loadPhotoWallSettings()
        let backgroundFileName = customBackgroundFileName(for: settings, family: context.family)
        let entry = PhotoEntry(
            date: now,
            photos: photos,
            layoutSeed: seed,
            backgroundStyle: settings.backgroundStyle,
            customBackgroundFileName: backgroundFileName
        )
        let refreshDate = nextDailyRefreshDate(from: now)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func photoCount(for family: WidgetKit.WidgetFamily) -> Int {
        switch family {
        case .systemMedium:
            return 6
        case .systemLarge:
            return 16
        default:
            return 16
        }
    }

    private func buildCandidatePool(from snapshot: WidgetPhotoSnapshot) -> [WidgetPhotoCandidate] {
        let favoriteIDs = Set(snapshot.favorites.map { $0.assetIdentifier })
        let kept = snapshot.kept.filter { !favoriteIDs.contains($0.assetIdentifier) }
        return snapshot.favorites + kept
    }

    private func pickCandidates(
        _ candidates: [WidgetPhotoCandidate],
        count: Int,
        seed: UInt64
    ) -> [WidgetPhotoCandidate] {
        guard !candidates.isEmpty else { return [] }
        var generator = SeededGenerator(seed: seed)
        let shuffled = candidates.shuffled(using: &generator)
        return Array(shuffled.prefix(count))
    }

    private func samplePhotos(count: Int) -> [PhotoItem] {
        let ratios: [CGFloat] = [1.0, 4.0 / 3.0, 3.0 / 4.0, 16.0 / 9.0]
        return (0..<count).map { index in
            PhotoItem(assetIdentifier: "", aspectRatio: ratios[index % ratios.count])
        }
    }

    private func normalizedAspectRatio(for original: Double) -> CGFloat {
        guard original > 0 else { return 4.0 / 3.0 }
        if original < 0.85 {
            return 3.0 / 4.0
        }
        if original < 1.15 {
            return 1.0
        }
        if original > 1.6 {
            return 16.0 / 9.0
        }
        return 4.0 / 3.0
    }

    private func dailySeed(for date: Date, refreshToken: String) -> UInt64 {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dayValue = UInt64(startOfDay.timeIntervalSince1970)
        return dayValue ^ stableHash(refreshToken)
    }

    private func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private func nextDailyRefreshDate(from date: Date) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86400)
    }

    private func customBackgroundFileName(
        for settings: PhotoWallSettings,
        family: WidgetKit.WidgetFamily
    ) -> String? {
        switch family {
        case .systemMedium:
            return settings.customBackgroundFileNameWide
                ?? settings.customBackgroundFileNameSquare
                ?? settings.customBackgroundFileName
        case .systemSmall, .systemLarge:
            return settings.customBackgroundFileNameSquare
                ?? settings.customBackgroundFileName
        default:
            return settings.customBackgroundFileNameSquare
                ?? settings.customBackgroundFileName
        }
    }
}

struct PhotoWallWidget: Widget {
    let kind: String = PhotoWallWidgetKind.name

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PhotoWallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("回忆墙")
        .description("展示您珍藏的照片回忆。")
        .supportedFamilies([.systemLarge, .systemMedium])
    }
}

struct PhotoWallWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let backgroundImage = loadBackgroundImage(fileName: entry.customBackgroundFileName)
        let content = ZStack {
            ScrapbookWallView(
                family: mapFamily(family),
                frameStyle: .blackMatte,
                backgroundStyle: entry.backgroundStyle,
                backgroundImage: backgroundImage,
                photos: entry.photos,
                layoutSeed: entry.layoutSeed
            )
        }

        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                Color(red: 0.1, green: 0.1, blue: 0.1)
            }
        } else {
            content.background(Color(red: 0.1, green: 0.1, blue: 0.1))
        }
    }

    private func loadBackgroundImage(fileName: String?) -> UIImage? {
        if let fileName,
           let data = WidgetPhotoStore.photoWallBackgroundData(for: fileName),
           let image = UIImage(data: data) {
            return image
        }
        if let data = WidgetPhotoStore.photoWallBackgroundData(),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    private func mapFamily(_ f: WidgetKit.WidgetFamily) -> PhotoWallFamily {
        switch f {
        case .systemSmall: return .systemSmall
        case .systemLarge: return .systemLarge
        case .systemMedium: return .systemMedium
        default: return .systemSmall
        }
    }
}

enum PhotoWallFamily {
    case systemSmall
    case systemMedium
    case systemLarge

    var grid: (rows: Int, columns: Int) {
        switch self {
        case .systemSmall:
            return (rows: 3, columns: 3)
        case .systemMedium:
            return (rows: 1, columns: 6)
        case .systemLarge:
            return (rows: 4, columns: 4)
        }
    }
}

enum FrameStyle {
    case blackMatte

    var color: Color {
        switch self {
        case .blackMatte:
            return Color(red: 0.04, green: 0.04, blue: 0.04)
        }
    }
}

struct ScrapbookWallView: View {
    let family: PhotoWallFamily
    let frameStyle: FrameStyle
    let backgroundStyle: PhotoWallBackgroundStyle
    let backgroundImage: UIImage?
    let photos: [PhotoItem]
    let layoutSeed: UInt64

    private var framePadding: CGFloat {
        family == .systemMedium ? 2 : 3
    }
    private let mattePadding: CGFloat = 3
    private let safePadding: CGFloat = 8
    private let layoutSafetyPadding: CGFloat = 3
    private let mediumCellInsetX: CGFloat = 0
    private let mediumCellInsetY: CGFloat = 0
    private let mediumScale: CGFloat = 1.2
    private let mediumJitter: CGFloat = 6
    private let mediumMaxRotation: CGFloat = 6
    private var outerCornerRadius: CGFloat {
        family == .systemMedium ? 22 : 18
    }

    private var innerCornerRadius: CGFloat {
        max(outerCornerRadius - framePadding, 0)
    }

    private var frameOuterPadding: CGFloat {
        0
    }

    private var widgetCornerRadius: CGFloat {
        family == .systemMedium ? 22 : 18
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layouts = buildLayouts(in: size)
            let backgroundInset = framePadding
            let backgroundSize = CGSize(
                width: max(size.width - backgroundInset * 2, 1),
                height: max(size.height - backgroundInset * 2, 1)
            )

            ZStack {
                backgroundLayer
                    .frame(width: backgroundSize.width, height: backgroundSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
                    .position(x: size.width * 0.5, y: size.height * 0.5)

                ZStack {
                    ForEach(layouts) { layout in
                        PhotoCardView(photo: layout.photo, targetSize: layout.size)
                            .frame(width: layout.size.width, height: layout.size.height)
                            .rotationEffect(.degrees(layout.rotation))
                            .position(layout.center)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .zIndex(layout.zIndex)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius).inset(by: contentInset))
            }
            .padding(frameOuterPadding)
            .clipShape(RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous))
            .overlay(frameBorderOverlay)
        }
    }

    private var frameBorderOverlay: some View {
        RoundedRectangle(cornerRadius: widgetCornerRadius, style: .continuous)
            .inset(by: framePadding * 0.5)
            .strokeBorder(frameStyle.color, lineWidth: framePadding)
            .allowsHitTesting(false)
    }

    private var backgroundLayer: some View {
        return ZStack {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let assetName = presetBackgroundAssetName(for: backgroundStyle) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(backgroundFillStyle(for: backgroundStyle))
            }
        }
    }

    private func presetBackgroundAssetName(for style: PhotoWallBackgroundStyle) -> String? {
        switch style {
        case .blackVelvet:
            return nil
        case .whitePaper:
            return "photo_wall_bg_white_paper"
        case .warmPaper:
            return "photo_wall_bg_warm_paper"
        case .newspaper:
            return "photo_wall_bg_newspaper"
        }
    }

    private func backgroundFillStyle(for style: PhotoWallBackgroundStyle) -> AnyShapeStyle {
        switch style {
        case .blackVelvet:
            return AnyShapeStyle(Color(red: 0.12, green: 0.12, blue: 0.12))
        case .whitePaper:
            return AnyShapeStyle(Color(red: 0.92, green: 0.92, blue: 0.9))
        case .warmPaper:
            return AnyShapeStyle(Color(red: 0.89, green: 0.84, blue: 0.74))
        case .newspaper:
            return AnyShapeStyle(Color(red: 0.78, green: 0.76, blue: 0.72))
        }
    }

    private func buildLayouts(in size: CGSize) -> [PhotoLayout] {
        let inset = contentInset
        let layoutInset = layoutSafeInset
        let contentSize = CGSize(
            width: max(size.width - inset * 2, 1),
            height: max(size.height - inset * 2, 1)
        )
        let contentRect = CGRect(origin: CGPoint(x: inset, y: inset), size: contentSize)
        let safeInset = layoutInset + cornerSafeInset
        let safeRect = CGRect(
            x: safeInset,
            y: safeInset,
            width: max(size.width - safeInset * 2, 1),
            height: max(size.height - safeInset * 2, 1)
        )
        let grid = family.grid
        let cellWidth = contentSize.width / CGFloat(grid.columns)
        let cellHeight = contentSize.height / CGFloat(grid.rows)

        var cells: [GridCell] = []
        cells.reserveCapacity(grid.rows * grid.columns)
        for row in 0..<grid.rows {
            for col in 0..<grid.columns {
                let centerY: CGFloat
                if family == .systemMedium {
                    centerY = contentRect.midY
                } else {
                    centerY = inset + cellHeight * (CGFloat(row) + 0.5)
                }
                let cellRect = CGRect(
                    x: contentRect.minX + cellWidth * CGFloat(col),
                    y: centerY - cellHeight * 0.5,
                    width: cellWidth,
                    height: cellHeight
                )
                let center = CGPoint(
                    x: inset + cellWidth * (CGFloat(col) + 0.5),
                    y: centerY
                )
                cells.append(GridCell(row: row, col: col, center: center, rect: cellRect))
            }
        }

        var generator = SeededGenerator(seed: layoutSeed)
        let shuffledCells = cells.shuffled(using: &generator)

        var layouts: [PhotoLayout] = []
        layouts.reserveCapacity(photos.count)

        for (index, photo) in photos.enumerated() {
            guard !shuffledCells.isEmpty else { break }
            let cell = shuffledCells[index % shuffledCells.count]
            let jitterXRange: CGFloat
            let jitterYRange: CGFloat
            if family == .systemMedium {
                jitterXRange = mediumJitter
                jitterYRange = mediumJitter
            } else {
                let jitterFactor: CGFloat = 0.15
                jitterXRange = cellWidth * jitterFactor
                jitterYRange = cellHeight * jitterFactor
            }

            var jitterX = randomSigned(using: &generator) * jitterXRange
            var jitterY = randomSigned(using: &generator) * jitterYRange

            if cell.col == 0 { jitterX = abs(jitterX) }
            if cell.col == grid.columns - 1 { jitterX = -abs(jitterX) }
            if cell.row == 0 { jitterY = abs(jitterY) }
            if cell.row == grid.rows - 1 { jitterY = -abs(jitterY) }

            let normalizedRatio = normalizedCardAspectRatio(photo.aspectRatio)
            var photoWidth: CGFloat
            var photoHeight: CGFloat
            if family == .systemMedium {
                let availableRect = cell.rect.insetBy(dx: mediumCellInsetX, dy: mediumCellInsetY)
                let fittedSize = fitSize(for: normalizedRatio, in: availableRect.size)
                photoWidth = fittedSize.width * mediumScale
                photoHeight = fittedSize.height * mediumScale
            } else {
                let baseWidthRatio = photoBaseWidthRatio(for: normalizedRatio)
                photoWidth = contentSize.width * baseWidthRatio
                photoHeight = photoWidth / max(normalizedRatio, 0.2)
            }

            let maxRotation: CGFloat = family == .systemMedium ? mediumMaxRotation : 12
            let rotation = Double(randomSigned(using: &generator) * maxRotation)
            let zIndex = Double(generator.next() % 1000)
            var center = CGPoint(x: cell.center.x + jitterX, y: cell.center.y + jitterY)

            let fitted = fitPhoto(
                center: center,
                size: CGSize(width: photoWidth, height: photoHeight),
                rotation: rotation,
                safeRect: family == .systemMedium
                    ? cell.rect.insetBy(dx: mediumCellInsetX, dy: mediumCellInsetY)
                    : safeRect
            )
            center = fitted.center
            photoWidth = fitted.size.width
            photoHeight = fitted.size.height

            layouts.append(
                PhotoLayout(
                    photo: photo,
                    center: center,
                    size: CGSize(width: photoWidth, height: photoHeight),
                    rotation: rotation,
                    zIndex: zIndex
                )
            )
        }

        return layouts
    }

    private func normalizedCardAspectRatio(_ ratio: CGFloat) -> CGFloat {
        guard ratio > 0 else { return 4.0 / 3.0 }
        if ratio < 0.85 {
            return 3.0 / 4.0
        }
        if ratio < 1.15 {
            return 1.0
        }
        if ratio > 1.6 {
            return 16.0 / 9.0
        }
        return 4.0 / 3.0
    }

    private func photoBaseWidthRatio(for ratio: CGFloat) -> CGFloat {
        var widthRatio: CGFloat
        switch ratio {
        case 3.0 / 4.0:
            widthRatio = 0.215
        case 1.0:
            widthRatio = 0.23
        case 16.0 / 9.0:
            widthRatio = 0.26
        default:
            widthRatio = 0.245
        }

        if family == .systemMedium {
            if ratio == 3.0 / 4.0 {
                return 0.19
            }
            widthRatio *= 0.85
        }

        return widthRatio
    }

    private func fitPhoto(
        center: CGPoint,
        size: CGSize,
        rotation: Double,
        safeRect: CGRect
    ) -> (center: CGPoint, size: CGSize) {
        let angle = CGFloat(abs(rotation)) * .pi / 180
        let cosA = abs(cos(angle))
        let sinA = abs(sin(angle))

        let rotatedWidth = size.width * cosA + size.height * sinA
        let rotatedHeight = size.width * sinA + size.height * cosA

        let scale = min(
            1.0,
            safeRect.width / max(rotatedWidth, 1),
            safeRect.height / max(rotatedHeight, 1)
        )
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let scaledRotatedWidth = rotatedWidth * scale
        let scaledRotatedHeight = rotatedHeight * scale
        let halfWidth = scaledRotatedWidth / 2
        let halfHeight = scaledRotatedHeight / 2

        let clampedX = clamp(center.x, min: safeRect.minX + halfWidth, max: safeRect.maxX - halfWidth)
        let clampedY = clamp(center.y, min: safeRect.minY + halfHeight, max: safeRect.maxY - halfHeight)

        return (CGPoint(x: clampedX, y: clampedY), scaledSize)
    }

    private func fitSize(for ratio: CGFloat, in maxSize: CGSize) -> CGSize {
        guard ratio > 0 else { return maxSize }
        var width = maxSize.width
        var height = width / ratio
        if height > maxSize.height {
            height = maxSize.height
            width = height * ratio
        }
        return CGSize(width: width, height: height)
    }

    private var contentInset: CGFloat {
        framePadding + mattePadding + safePadding
    }

    private var layoutSafeInset: CGFloat {
        contentInset + layoutSafetyPadding
    }

    private var cornerSafeInset: CGFloat {
        innerCornerRadius * (1 - 1 / CGFloat(sqrt(2.0)))
    }
}

private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    Swift.max(min, Swift.min(max, value))
}

struct PhotoLayout: Identifiable {
    let id = UUID()
    let photo: PhotoItem
    let center: CGPoint
    let size: CGSize
    let rotation: Double
    let zIndex: Double
}

struct GridCell {
    let row: Int
    let col: Int
    let center: CGPoint
    let rect: CGRect
}

struct PhotoCardView: View {
    let photo: PhotoItem
    let targetSize: CGSize

    var body: some View {
        ZStack {
            Color.white
            if let data = photo.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .padding(EdgeInsets(top: 3, leading: 3, bottom: 12, trailing: 3))
                    .clipped()
            } else {
                Color.gray.opacity(0.25)
                    .padding(EdgeInsets(top: 3, leading: 3, bottom: 12, trailing: 3))
            }
        }
        .cornerRadius(2)
        .clipped()
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x4d595df4d0f33173 : seed
    }

    mutating func next() -> UInt64 {
        state &*= 6364136223846793005
        state &+= 1
        return state
    }
}

private func randomSigned(using generator: inout SeededGenerator) -> CGFloat {
    let value = Double(generator.next()) / Double(UInt64.max)
    return CGFloat(value * 2.0 - 1.0)
}
