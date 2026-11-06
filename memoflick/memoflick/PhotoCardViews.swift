//
//  PhotoCardViews.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import SwiftUI
import Photos

struct PhotoCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let newValue = nextValue() {
            value = newValue
        }
    }
}

struct PhotoCardStack: View {
    let items: [PhotoReviewItem]
    @Binding var pendingSwipe: PhotoReviewViewModel.SwipeDirection?
    @Binding var shouldMarkFavoriteForPendingSwipe: Bool
    @Binding var activeDirection: PhotoSwipeHintDirection?
    @Binding var undoDirection: PhotoReviewViewModel.SwipeDirection?
    let onSwipe: (PhotoReviewViewModel.SwipeDirection, Bool) -> Void
    let onFavoriteSwipe: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isPerformingProgrammaticSwipe = false
    @State private var undoOffset: CGSize = .zero
    private let swipeThresholdRatio: CGFloat = 0.28

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let displayedItems = Array(items.prefix(3))
                ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, element in
                    let position = index
                    let size = cardSize(for: element, in: geometry.size)
                    let isTop = position == 0
                    let combinedOffset = isTop
                        ? CGSize(
                            width: dragOffset.width + undoOffset.width,
                            height: dragOffset.height + undoOffset.height
                        )
                        : .zero
                    PhotoCardView(item: element)
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(scale(for: position))
                        .offset(y: offsetY(for: position, cardHeight: size.height))
                        .offset(combinedOffset)
                        .rotationEffect(isTop ? rotation(for: combinedOffset) : .zero)
                        .background(
                            GeometryReader { innerGeo in
                                Color.clear.preference(
                                    key: PhotoCardFramePreferenceKey.self,
                                    value: isTop ? innerGeo.frame(in: .named("photoReview")) : nil
                                )
                            }
                        )
                        .overlay(alignment: .topLeading) {
                            SwipeIndicator(type: .nope)
                                .opacity(position == 0 && activeDirection == .delete ? 1 : 0)
                                .padding(16)
                                .animation(.easeInOut(duration: 0.12), value: activeDirection)
                        }
                        .overlay(alignment: .topTrailing) {
                            SwipeIndicator(type: .like)
                                .opacity(position == 0 && activeDirection == .keep ? 1 : 0)
                                .padding(16)
                                .animation(.easeInOut(duration: 0.12), value: activeDirection)
                        }
                        .overlay(alignment: .center) {
                            FavoriteSwipeOverlay()
                                .opacity(position == 0 && activeDirection == .favorite ? 1 : 0)
                        }
                        .opacity(opacity(for: position, cardWidth: size.width))
                        .shadow(color: Color.black.opacity(position == 0 ? 0.2 : 0.1), radius: position == 0 ? 14 : 8, x: 0, y: position == 0 ? 12 : 6)
                        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: dragOffset)
                        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: items.map { $0.id })
                        .zIndex(Double(displayedItems.count - position))
                        .allowsHitTesting(position == 0)
                        .gesture(position == 0 ? dragGesture(in: geometry, cardWidth: size.width) : nil)
                }
            }
            .onChange(of: pendingSwipe) { newValue in
                guard let newValue, !isPerformingProgrammaticSwipe, !items.isEmpty else {
                    return
                }
                performProgrammaticSwipe(newValue, geometry: geometry)
            }
            .onChange(of: undoDirection) { newValue in
                guard let newValue else { return }
                guard !items.isEmpty else {
                    undoDirection = nil
                    return
                }
                let horizontal = geometry.size.width * 1.1
                undoOffset = CGSize(
                    width: newValue == .keep ? horizontal : -horizontal,
                    height: -40
                )
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    undoOffset = .zero
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    undoDirection = nil
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dragGesture(in geometry: GeometryProxy, cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = value.translation
                activeDirection = resolvedDirection(for: value.translation, cardSize: geometry.size)
            }
            .onEnded { value in
                let horizontalThreshold = cardWidth * swipeThresholdRatio
                let verticalThreshold = geometry.size.height * 0.2
                let resolved = resolvedDirection(for: value.translation, cardSize: geometry.size)

                switch resolved {
                case .favorite:
                    if value.translation.height < -verticalThreshold {
                        animateFavoriteSwipe(geometry: geometry)
                    } else {
                        resetDragState()
                    }
                case .keep, .delete:
                    let shouldTrigger = abs(value.translation.width) > horizontalThreshold
                    let direction = horizontalDirection(for: value.translation.width)
                    if shouldTrigger {
                        animateSwipe(direction, geometry: geometry, markFavorite: false)
                    } else {
                        resetDragState()
                    }
                case nil:
                    resetDragState()
                }
            }
    }

    private func resetDragState() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            dragOffset = .zero
            activeDirection = nil
        }
    }

    private func resolvedDirection(for translation: CGSize, cardSize: CGSize) -> PhotoSwipeHintDirection? {
        let horizontal = translation.width
        let vertical = translation.height
        let verticalThreshold = cardSize.height * 0.18
        let horizontalThreshold: CGFloat = 12

        if vertical < -verticalThreshold && abs(vertical) > abs(horizontal) {
            return .favorite
        }
        if abs(horizontal) > horizontalThreshold {
            return horizontal >= 0 ? .keep : .delete
        }
        return nil
    }

    private func horizontalDirection(for horizontal: CGFloat) -> PhotoReviewViewModel.SwipeDirection {
        horizontal >= 0 ? .keep : .delete
    }

    private func performProgrammaticSwipe(_ direction: PhotoReviewViewModel.SwipeDirection, geometry: GeometryProxy) {
        isPerformingProgrammaticSwipe = true
        activeDirection = direction == .keep ? .keep : .delete
        let markFavorite = shouldMarkFavoriteForPendingSwipe && direction == .keep
        animateSwipe(direction, geometry: geometry, markFavorite: markFavorite)
    }

    private func animateFavoriteSwipe(geometry: GeometryProxy) {
        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = CGSize(width: 0, height: -geometry.size.height * 0.65)
        }

        Task {
            try? await Task.sleep(nanoseconds: 170_000_000)
            await MainActor.run {
                dragOffset = .zero
                activeDirection = nil
                onFavoriteSwipe()
                shouldMarkFavoriteForPendingSwipe = false
            }
        }
    }

    private func animateSwipe(
        _ direction: PhotoReviewViewModel.SwipeDirection,
        geometry: GeometryProxy,
        markFavorite: Bool
    ) {
        let horizontal: CGFloat = (direction == .keep ? 1 : -1) * geometry.size.width * 1.4
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = CGSize(width: horizontal, height: -40)
        }

        Task {
            try? await Task.sleep(nanoseconds: 170_000_000)
            await MainActor.run {
                dragOffset = .zero
                activeDirection = nil
                pendingSwipe = nil
                isPerformingProgrammaticSwipe = false
                onSwipe(direction, markFavorite)
                shouldMarkFavoriteForPendingSwipe = false
            }
        }
    }

    private func scale(for position: Int) -> CGFloat {
        switch position {
        case 0: return 1.0
        case 1: return 0.92
        default: return 0.88
        }
    }

    private func offsetY(for position: Int, cardHeight: CGFloat) -> CGFloat {
        switch position {
        case 0: return 0
        case 1: return cardHeight * 0.06
        default: return cardHeight * 0.12
        }
    }

    private func rotation(for offset: CGSize) -> Angle {
        Angle(degrees: Double(offset.width / 20))
    }

    private func opacity(for position: Int, cardWidth: CGFloat) -> Double {
        switch position {
        case 0:
            return 1
        case 1:
            guard cardWidth > 0 else { return 0 }
            let progress = min(abs(dragOffset.width) / cardWidth, 1)
            return progress * 0.5
        default:
            return 0
        }
    }

    private func cardSize(for item: PhotoReviewItem, in available: CGSize) -> CGSize {
        // 仅控制包围盒，不改变原始纵横比
        let horizontalMargin: CGFloat = 24
        let verticalMargin: CGFloat = 24
        let maxWidth = max(available.width - horizontalMargin * 2, 220)
        let maxHeight = max(available.height - verticalMargin * 2, 240)

        let pixelWidth = max(CGFloat(item.pixelWidth), 1)
        let pixelHeight = max(CGFloat(item.pixelHeight), 1)
        let aspect = pixelHeight / pixelWidth

        var targetWidth = maxWidth
        var targetHeight = targetWidth * aspect

        if targetHeight > maxHeight {
            targetHeight = maxHeight
            targetWidth = targetHeight / aspect
        }

        let minWidth: CGFloat = 220
        let minHeight: CGFloat = 240
        targetWidth = max(targetWidth, minWidth)
        targetHeight = max(targetHeight, minHeight)

        if targetWidth > maxWidth {
            targetWidth = maxWidth
            targetHeight = targetWidth * aspect
        }
        if targetHeight > maxHeight {
            targetHeight = maxHeight
            targetWidth = targetHeight / aspect
        }

        return CGSize(width: targetWidth, height: targetHeight)
    }
}

struct PhotoCardView: View {
    let item: PhotoReviewItem
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    private let imageManager = PHCachingImageManager()
    @Environment(\.appTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.mediaPlaceholderBackground)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                }
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    let overlayForeground = overlayForegroundColor
                    let overlayBackground = overlayBackgroundColor

                    Text(item.displayDate)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(overlayForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(overlayBackground, in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
        }
        .onAppear(perform: loadImageIfNeeded)
        .onDisappear(perform: cancelRequest)
    }

    private func loadImageIfNeeded() {
        guard image == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let aspect = CGFloat(item.pixelHeight) / max(CGFloat(item.pixelWidth), 1)
        let baseWidth: CGFloat = 900
        let targetSize = CGSize(width: baseWidth, height: baseWidth * aspect)
        guard let asset = item.asset else {
            if let testImage = item.testImage?.image {
                image = testImage
            }
            return
        }

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                image = result
            }
        }
    }

    private func cancelRequest() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }

    private var overlayForegroundColor: Color {
        let brightness = item.meta.metrics.averageBrightness
        return brightness > 0.6 ? Color.black.opacity(0.85) : Color.white
    }

    private var overlayBackgroundColor: Color {
        let brightness = item.meta.metrics.averageBrightness
        return brightness > 0.6 ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }
}

private struct SwipeIndicator: View {
    enum IndicatorType {
        case like
        case nope
    }

    let type: IndicatorType

    var body: some View {
        Group {
            switch type {
            case .like:
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#00F0A9"), lineWidth: 3)
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(hex: "#00F0A9"))
                }
            case .nope:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "#6F86C9"))
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 6)
    }
}

private struct FavoriteSwipeOverlay: View {
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: 92, height: 92)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
            .overlay {
                Image(systemName: "star.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color(hex: "#3498db"))
            }
    }
}
