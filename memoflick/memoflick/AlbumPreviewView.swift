import SwiftUI
import Photos
import AVKit
import UIKit
import CoreImage

struct AlbumPreviewView: View {
    let items: [AlbumMediaItem]
    @Binding var selectedItemID: String?
    let currentTab: AlbumView.Tab
    let onClose: () -> Void
    let onFavorite: (AlbumMediaItem) -> Void
    let onMoveToTrash: (AlbumMediaItem) -> Void
    let onInsertNewItem: (AlbumMediaItem) -> Void

    @State private var showResizeOverlay = false
    @State private var showDiarySheet = false
    @State private var currentDiary: String?
    @State private var adaptiveColor: Color = .white
    @State private var currentAssetSize: Int64?
    @State private var isResizing = false
    @State private var alertMessage: String?
    @StateObject private var sizeStore = AssetSizeStore.shared

    private var currentItem: AlbumMediaItem? {
        guard let id = selectedItemID else { return nil }
        return items.first(where: { $0.id == id })
    }

    private var diaryAvailable: Bool {
        guard let item = currentItem else { return false }
        let hasDiary = !(item.caption?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return currentTab == .collections && item.isFavorite && hasDiary
    }

    private var currentDateText: String? {
        guard let text = currentItem?.displayDate else { return nil }
        let parts = text.split(separator: " ")
        return parts.first.map(String.init)
    }

    private var currentTimeText: String? {
        guard let item = currentItem else { return nil }
        if item.mediaType == .video, let duration = item.durationLabel {
            return duration
        }
        let parts = item.displayDate.split(separator: " ")
        return parts.count >= 2 ? String(parts.last!) : nil
    }

    private var currentIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return items.firstIndex(where: { $0.id == id })
    }

    private var canGoPrevious: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }

    private var canGoNext: Bool {
        guard let index = currentIndex else { return false }
        return index < items.count - 1
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = layoutMetrics(for: proxy)
            let viewportWidth = layout.viewportWidth
            let viewportHeight = layout.viewportHeight
            let topBarHeight = layout.topBarHeight
            let bottomBarHeight = layout.bottomBarHeight
            let topInset = proxy.safeAreaInsets.top
            let bottomInset = proxy.safeAreaInsets.bottom

            Color.black
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 0) {
                        topBar(topInset: topInset, height: topBarHeight)

                        ZStack {
                            Color.black
                            mediaPager
                                .frame(width: viewportWidth, height: viewportHeight)
                                .clipped()
                            navigationArrows
                        }
                        .frame(maxWidth: .infinity, minHeight: viewportHeight, maxHeight: viewportHeight, alignment: .center)

                        bottomToolbar(bottomInset: bottomInset, height: bottomBarHeight)
                    }
                )
                .blur(radius: showResizeOverlay ? 6 : 0)
                .overlay {
                    if showResizeOverlay {
                        ResizeOverlay(
                            currentSize: formattedSize(currentAssetSize),
                            isProcessing: isResizing,
                            onCancel: { showResizeOverlay = false },
                            onConfirm: { value, unit in
                                Task { await performResize(targetValue: value, unit: unit) }
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .sheet(isPresented: $showDiarySheet) {
            if let diary = currentDiary {
                DiarySheetView(text: diary) {
                    showDiarySheet = false
                }
                .presentationDetents([.fraction(0.35), .medium])
            }
        }
        .alert(
            alertMessage ?? "",
            isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } }),
            actions: {
                Button("好", role: .cancel) { alertMessage = nil }
            }
        )
        .onAppear {
            Task { await updateCurrentAssetSize() }
        }
        .onChange(of: selectedItemID) { _ in
            Task { await updateCurrentAssetSize() }
        }
    }

    private func topBar(topInset: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea(edges: .top)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.3), in: Circle())
                }

                Spacer()

                VStack(spacing: 4) {
                    if let date = currentDateText {
                        Text(date)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    if let time = currentTimeText {
                        Text(time)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.top, topInset + 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .center)
    }

    private func bottomToolbar(bottomInset: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let item = currentItem {
                HStack(spacing: 22) {
                    ToolButton(icon: "square.and.arrow.up") {
                        // Share placeholder
                    }

                    let favoriteDisabled = item.isFavorite || currentTab == .collections
                    ToolButton(icon: "star.fill", disabled: favoriteDisabled) {
                        onFavorite(item)
                    }

                    if item.mediaType == .photo {
                        ToolButton(icon: "slider.horizontal.3") {
                            showResizeOverlay = true
                        }
                    }

                    let diaryDisabled = !diaryAvailable
                    ToolButton(icon: "text.book.closed", disabled: diaryDisabled) {
                        currentDiary = item.caption
                        showDiarySheet = true
                    }

                    let deleteDisabled = currentTab == .trash
                    ToolButton(icon: "trash", disabled: deleteDisabled, tint: deleteDisabled ? .gray : .red) {
                        onMoveToTrash(item)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 18)
                .padding(.bottom, max(18, bottomInset + 8))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .center)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }

    private var navigationArrows: some View {
        HStack {
            NavArrowButton(direction: .left, disabled: !canGoPrevious) {
                moveToPrevious()
            }
            Spacer()
            NavArrowButton(direction: .right, disabled: !canGoNext) {
                moveToNext()
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var mediaPager: some View {
        TabView(selection: $selectedItemID) {
            ForEach(items) { item in
                AlbumPreviewPage(item: item)
                    .tag(Optional(item.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - Layout helper

    private func layoutMetrics(for proxy: GeometryProxy) -> (viewportWidth: CGFloat, viewportHeight: CGFloat, topBarHeight: CGFloat, bottomBarHeight: CGFloat) {
        let screenW = proxy.size.width
        let screenH = proxy.size.height
        let bottomInset = proxy.safeAreaInsets.bottom
        let topInset = proxy.safeAreaInsets.top

        let minTopHeight: CGFloat = max(52, topInset + 12)
        let minBottomHeight: CGFloat = max(88, 56 + bottomInset)
        let idealViewportHeight = screenW * 16 / 9

        let remainingAfterBars = screenH - (minTopHeight + minBottomHeight)

        var viewportHeight = idealViewportHeight
        var viewportWidth = screenW
        var topBarHeight = minTopHeight
        var bottomBarHeight = minBottomHeight

        if idealViewportHeight <= remainingAfterBars {
            let extra = remainingAfterBars - idealViewportHeight
            topBarHeight += extra / 2
            bottomBarHeight += extra / 2
        } else {
            viewportHeight = max(0, remainingAfterBars)
            viewportWidth = viewportHeight * 9 / 16
        }

        // 整体增加顶部栏高度 60px
        let adjustedTopBarHeight = topBarHeight + 60

        return (viewportWidth, viewportHeight, adjustedTopBarHeight, bottomBarHeight)
    }

    // MARK: - Resize helpers

    private func performResize(targetValue: String, unit: SizeUnit) async {
        guard !isResizing else { return }
        guard let item = currentItem, item.mediaType == .photo else {
            await MainActor.run { alertMessage = "仅支持照片调整大小" }
            return
        }
        guard let targetNumber = Double(targetValue.trimmingCharacters(in: .whitespaces)),
              targetNumber > 0 else {
            await MainActor.run { alertMessage = "请输入有效的目标大小" }
            return
        }
        guard let asset = item.asset else {
            await MainActor.run { alertMessage = "未找到原始照片资源" }
            return
        }

        isResizing = true

        do {
            let targetBytes = unit == .mb
                ? Int64(targetNumber * 1024 * 1024)
                : Int64(targetNumber * 1024)
            let data = try await loadImageData(for: asset)
            let compressed = try await compressJPEGData(data, targetBytes: targetBytes)
            let createdAsset = try await saveCompressedPhoto(compressed.data, from: asset)
            let newItem = AlbumMediaItem(asset: createdAsset, compressedSizeBytes: compressed.actualBytes)
            await MainActor.run {
                currentAssetSize = compressed.actualBytes
                alertMessage = "已生成约 \(formattedSize(compressed.actualBytes)) 的副本"
                showResizeOverlay = false
                onInsertNewItem(newItem)
                isResizing = false
            }
        } catch {
            await MainActor.run {
                alertMessage = "调整失败：\(error.localizedDescription)"
                isResizing = false
            }
        }
    }

    private func loadImageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data else {
                    continuation.resume(throwing: NSError(domain: "Resize", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取原始照片数据"]))
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func compressJPEGData(_ data: Data, targetBytes: Int64) async throws -> (data: Data, actualBytes: Int64) {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "Resize", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法解码图片"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    let minQuality: CGFloat = 0.05
                    var low: CGFloat = minQuality
                    var high: CGFloat = 1.0
                    var bestData: Data = data

                    for _ in 0..<7 {
                        let mid = (low + high) / 2
                        guard let compressed = image.jpegData(compressionQuality: mid) else { continue }
                        bestData = compressed
                        if Int64(compressed.count) > targetBytes {
                            high = mid
                        } else {
                            low = mid
                        }
                    }

                    if Int64(bestData.count) > targetBytes, let compressed = image.jpegData(compressionQuality: minQuality) {
                        bestData = compressed
                    }

                    continuation.resume(returning: (bestData, Int64(bestData.count)))
                }
            }
        }
    }

    private func saveCompressedPhoto(_ data: Data, from sourceAsset: PHAsset) async throws -> PHAsset {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try data.write(to: tempURL)
        var placeholder: PHObjectPlaceholder?
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .photo, fileURL: tempURL, options: options)
                // 使用当前时间作为新资源的创建时间，便于在系统相册和应用中排序到最新
                creationRequest.creationDate = Date()
                creationRequest.location = sourceAsset.location
                placeholder = creationRequest.placeholderForCreatedAsset
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    if let localId = placeholder?.localIdentifier {
                        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                        if let newAsset = fetchResult.firstObject {
                            continuation.resume(returning: newAsset)
                            return
                        }
                    }
                    continuation.resume(throwing: NSError(domain: "Resize", code: -3, userInfo: [NSLocalizedDescriptionKey: "未能获取新建资源"]))
                } else {
                    continuation.resume(throwing: NSError(domain: "Resize", code: -4, userInfo: [NSLocalizedDescriptionKey: "保存副本失败"]))
                }
            }
        }
    }

    @MainActor
    private func updateCurrentAssetSize() async {
        guard let asset = currentItem?.asset else {
            currentAssetSize = nil
            return
        }
        let assetID = asset.localIdentifier
        if let cached = sizeStore.cachedSize(for: assetID) {
            currentAssetSize = cached
            return
        }
        currentAssetSize = nil
        let size = await sizeStore.requestSize(for: assetID, allowNetworkAccess: true)
        guard currentItem?.asset?.localIdentifier == assetID else { return }
        currentAssetSize = size
    }

    private func formattedSize(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else { return "未知" }
        let mb = Double(bytes) / 1024 / 1024
        if mb >= 1 {
            return String(format: "%.2f MB", mb)
        }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }

    private func moveToPrevious() {
        guard let index = currentIndex, index > 0 else { return }
        selectedItemID = items[index - 1].id
    }

    private func moveToNext() {
        guard let index = currentIndex, index < items.count - 1 else { return }
        selectedItemID = items[index + 1].id
    }

    // MARK: - Adaptive Color

    private func updateAdaptiveColor(for item: AlbumMediaItem) {
        let threshold: CGFloat = 0.6
        adaptiveColor = .white

        if item.mediaType == .photo {
            fetchPhotoPreview(for: item) { image in
                guard let image, let brightness = averageBrightness(for: image) else { return }
                let color: Color = brightness > threshold ? .black : .white
                withAnimation(.linear(duration: 0.15)) {
                    adaptiveColor = color
                }
            }
        } else {
            fetchVideoFrame(for: item) { image in
                guard let image, let brightness = averageBrightness(for: image) else { return }
                let color: Color = brightness > threshold ? .black : .white
                withAnimation(.linear(duration: 0.15)) {
                    adaptiveColor = color
                }
            }
        }
    }

    private func fetchPhotoPreview(for item: AlbumMediaItem, completion: @escaping (UIImage?) -> Void) {
        if let testImage = item.testImage?.image {
            completion(testImage)
            return
        }
        guard let asset = item.asset else {
            completion(nil)
            return
        }
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    private func fetchVideoFrame(for item: AlbumMediaItem, completion: @escaping (UIImage?) -> Void) {
        guard let asset = item.asset else {
            completion(nil)
            return
        }
        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
            guard let avAsset else {
                completion(nil)
                return
            }
            let generator = AVAssetImageGenerator(asset: avAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 200, height: 200)
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    private func averageBrightness(for image: UIImage) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let params: [String: Any] = [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: extent)]
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: params),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        let r = CGFloat(bitmap[0]) / 255.0
        let g = CGFloat(bitmap[1]) / 255.0
        let b = CGFloat(bitmap[2]) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

private struct AlbumPreviewPage: View {
    let item: AlbumMediaItem
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    @State private var player: AVPlayer?
    private let imageManager = PHCachingImageManager()

    var body: some View {
        ZStack {
            switch item.mediaType {
            case .photo:
                photoBody
            case .video:
                videoBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            loadImageIfNeeded()
            loadVideoIfNeeded()
        }
        .onDisappear(perform: cancel)
    }

    @ViewBuilder
    private var photoBody: some View {
        if let image {
            GeometryReader { geometry in
                let size = geometry.size
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.width, maxHeight: size.height)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    @ViewBuilder
    private var videoBody: some View {
        if let player {
            VideoPlayer(player: player)
                .onAppear { player.play() }
                .onDisappear { player.pause() }
        } else {
            ProgressView().tint(.white)
        }
    }

    private func loadImageIfNeeded() {
        guard item.mediaType == .photo else { return }
        guard image == nil else { return }
        if let testImage = item.testImage?.image {
            image = testImage
            return
        }
        guard let asset = item.asset else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        requestID = imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            if let result {
                image = result
            }
        }
    }

    private func cancel() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
        player?.pause()
    }

    private func loadVideoIfNeeded() {
        guard item.mediaType == .video else { return }
        guard player == nil else { return }
        guard let asset = item.asset else { return }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset else { return }
            let item = AVPlayerItem(asset: avAsset)
            DispatchQueue.main.async {
                player = AVPlayer(playerItem: item)
            }
        }
    }
}

private enum ArrowDirection {
    case left, right
}

private struct NavArrowButton: View {
    let direction: ArrowDirection
    var disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
    }
}

private struct ToolButton: View {
    let icon: String
    var disabled: Bool = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(disabled ? .gray : tint)
                .frame(width: 50, height: 50)
                .background(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
        .disabled(disabled)
    }
}

private struct DiarySheetView: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 42, height: 5)
                .padding(.top, 8)

            HStack {
                Text("日记")
                    .font(.headline)
                Spacer()
                Button("关闭") { onClose() }
                    .font(.subheadline)
            }

            ScrollView {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 240)

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Resize Overlay

private enum SizeUnit: String, CaseIterable, Identifiable {
    case mb = "MB"
    case kb = "KB"
    var id: String { rawValue }
}

private struct ResizeOverlay: View {
    let currentSize: String
    let isProcessing: Bool
    let onCancel: () -> Void
    let onConfirm: (String, SizeUnit) -> Void

    @State private var inputValue: String = ""
    @State private var unit: SizeUnit = .mb

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("调整照片容量")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("当前: \(currentSize)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 10) {
                    TextField("输入目标大小", text: $inputValue)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    Picker("", selection: $unit) {
                        ForEach(SizeUnit.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    Button(action: { onConfirm(inputValue, unit) }) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("确定")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isProcessing || inputValue.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        }
    }
}
