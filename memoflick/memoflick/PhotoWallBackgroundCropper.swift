import SwiftUI
import UIKit

struct PhotoWallBackgroundCropper: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage, UIImage) -> Void

    @Environment(\.localizer) private var localizer
    @State private var selectedAspect: CropAspect = .square
    @State private var squareState = CropState()
    @State private var wideState = CropState()
    @State private var cropContainerSize: CGSize = .zero

    private let normalizedImage: UIImage
    private let cropPadding: CGFloat = 24
    private let cropCornerRadius: CGFloat = 14

    init(
        image: UIImage,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (UIImage, UIImage) -> Void
    ) {
        self.image = image
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.normalizedImage = image.normalizedForCrop()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                GeometryReader { proxy in
                    let container = proxy.size
                    let cropSize = cropSize(for: container, ratio: selectedAspect.ratio)
                    ZStack {
                        PhotoWallCropperScrollView(
                            image: normalizedImage,
                            cropSize: cropSize,
                            state: activeCropState
                        )
                        .frame(width: cropSize.width, height: cropSize.height)

                        RoundedRectangle(cornerRadius: cropCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.85), lineWidth: 1)
                            .frame(width: cropSize.width, height: cropSize.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        cropContainerSize = container
                    }
                    .onChange(of: container) { newValue in
                        cropContainerSize = newValue
                    }
                }
                footer
            }
        }
    }

    private var header: some View {
        HStack {
            Button(localizer.text(.actionCancel)) {
                onCancel()
            }
            .foregroundStyle(.white)

            Spacer()

            Button(localizer.text(.actionConfirm)) {
                handleConfirm()
            }
            .foregroundStyle(.white)
            .disabled(cropContainerSize.width <= 0 || cropContainerSize.height <= 0)
            .opacity(cropContainerSize.width <= 0 || cropContainerSize.height <= 0 ? 0.5 : 1)
        }
        .overlay(
            Text(localizer.text(.photoWallBackgroundCropTitle))
                .font(.headline)
                .foregroundStyle(.white)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                aspectButton(.square, title: localizer.text(.photoWallBackgroundCropSquare))
                aspectButton(.wide, title: localizer.text(.photoWallBackgroundCropWide))
            }
            .padding(.horizontal, 20)

            Text(localizer.text(.photoWallBackgroundCropHint))
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 20)
    }

    private func aspectButton(_ aspect: CropAspect, title: String) -> some View {
        let isSelected = selectedAspect == aspect
        return Button {
            selectedAspect = aspect
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.white : Color.white.opacity(0.2),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private var activeCropState: Binding<CropState> {
        switch selectedAspect {
        case .square:
            return $squareState
        case .wide:
            return $wideState
        }
    }

    private func handleConfirm() {
        guard cropContainerSize.width > 0, cropContainerSize.height > 0 else { return }
        let squareSize = cropSize(for: cropContainerSize, ratio: CropAspect.square.ratio)
        let wideSize = cropSize(for: cropContainerSize, ratio: CropAspect.wide.ratio)
        guard
            let squareImage = croppedImage(from: squareState, cropSize: squareSize),
            let wideImage = croppedImage(from: wideState, cropSize: wideSize)
        else { return }
        onConfirm(squareImage, wideImage)
    }

    private func cropSize(for container: CGSize, ratio: CGFloat) -> CGSize {
        let maxWidth = max(container.width - cropPadding * 2, 1)
        let maxHeight = max(container.height - cropPadding * 2, 1)
        var width = maxWidth
        var height = width / ratio
        if height > maxHeight {
            height = maxHeight
            width = height * ratio
        }
        return CGSize(width: width, height: height)
    }

    private func croppedImage(from state: CropState, cropSize: CGSize) -> UIImage? {
        let minScale = minZoomScale(for: cropSize)
        let zoomScale = state.hasUserAdjusted ? max(state.zoomScale, minScale) : minScale
        let offset = state.hasUserAdjusted
            ? clampedOffset(state.contentOffset, zoomScale: zoomScale, cropSize: cropSize)
            : centeredOffset(zoomScale: zoomScale, cropSize: cropSize)
        let scale = 1 / max(zoomScale, 0.0001)
        let cropRect = CGRect(
            x: offset.x * scale,
            y: offset.y * scale,
            width: cropSize.width * scale,
            height: cropSize.height * scale
        ).intersection(CGRect(origin: .zero, size: normalizedImage.size))
        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        let pixelRect = CGRect(
            x: cropRect.origin.x * normalizedImage.scale,
            y: cropRect.origin.y * normalizedImage.scale,
            width: cropRect.size.width * normalizedImage.scale,
            height: cropRect.size.height * normalizedImage.scale
        ).integral
        guard let cgImage = normalizedImage.cgImage?.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
    }

    private func minZoomScale(for cropSize: CGSize) -> CGFloat {
        let widthScale = cropSize.width / max(normalizedImage.size.width, 1)
        let heightScale = cropSize.height / max(normalizedImage.size.height, 1)
        return max(widthScale, heightScale)
    }

    private func centeredOffset(zoomScale: CGFloat, cropSize: CGSize) -> CGPoint {
        let scaledSize = CGSize(
            width: normalizedImage.size.width * zoomScale,
            height: normalizedImage.size.height * zoomScale
        )
        let offsetX = max((scaledSize.width - cropSize.width) / 2, 0)
        let offsetY = max((scaledSize.height - cropSize.height) / 2, 0)
        return CGPoint(x: offsetX, y: offsetY)
    }

    private func clampedOffset(_ offset: CGPoint, zoomScale: CGFloat, cropSize: CGSize) -> CGPoint {
        let scaledSize = CGSize(
            width: normalizedImage.size.width * zoomScale,
            height: normalizedImage.size.height * zoomScale
        )
        let maxOffsetX = max(scaledSize.width - cropSize.width, 0)
        let maxOffsetY = max(scaledSize.height - cropSize.height, 0)
        return CGPoint(
            x: min(max(offset.x, 0), maxOffsetX),
            y: min(max(offset.y, 0), maxOffsetY)
        )
    }
}

private enum CropAspect: CaseIterable {
    case square
    case wide

    var ratio: CGFloat {
        switch self {
        case .square:
            return 1.0
        case .wide:
            return 2.0
        }
    }
}

private struct CropState: Equatable {
    var zoomScale: CGFloat = 1
    var contentOffset: CGPoint = .zero
    var hasUserAdjusted: Bool = false
}

private struct PhotoWallCropperScrollView: UIViewRepresentable {
    let image: UIImage
    let cropSize: CGSize
    @Binding var state: CropState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: $state)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.delegate = context.coordinator
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.addSubview(imageView)
        scrollView.contentSize = image.size
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard cropSize.width > 0, cropSize.height > 0 else { return }

        if context.coordinator.imageView?.image !== image {
            context.coordinator.imageView?.image = image
            context.coordinator.imageView?.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
        }

        let widthScale = cropSize.width / max(image.size.width, 1)
        let heightScale = cropSize.height / max(image.size.height, 1)
        let minScale = max(widthScale, heightScale)
        let maxScale = max(minScale * 4, minScale + 1)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale

        let targetZoom: CGFloat
        let targetOffset: CGPoint
        if state.hasUserAdjusted {
            targetZoom = max(state.zoomScale, minScale)
            targetOffset = clampedOffset(state.contentOffset, zoomScale: targetZoom)
        } else {
            targetZoom = minScale
            targetOffset = centeredOffset(zoomScale: targetZoom)
        }

        context.coordinator.isApplyingState = true
        if abs(scrollView.zoomScale - targetZoom) > 0.001 {
            scrollView.setZoomScale(targetZoom, animated: false)
        }
        if scrollView.contentOffset != targetOffset {
            scrollView.setContentOffset(targetOffset, animated: false)
        }
        context.coordinator.isApplyingState = false

        if state.zoomScale != targetZoom || state.contentOffset != targetOffset {
            DispatchQueue.main.async {
                state.zoomScale = targetZoom
                state.contentOffset = targetOffset
            }
        }
    }

    private func centeredOffset(zoomScale: CGFloat) -> CGPoint {
        let scaledSize = CGSize(width: image.size.width * zoomScale, height: image.size.height * zoomScale)
        let offsetX = max((scaledSize.width - cropSize.width) / 2, 0)
        let offsetY = max((scaledSize.height - cropSize.height) / 2, 0)
        return CGPoint(x: offsetX, y: offsetY)
    }

    private func clampedOffset(_ offset: CGPoint, zoomScale: CGFloat) -> CGPoint {
        let scaledSize = CGSize(width: image.size.width * zoomScale, height: image.size.height * zoomScale)
        let maxOffsetX = max(scaledSize.width - cropSize.width, 0)
        let maxOffsetY = max(scaledSize.height - cropSize.height, 0)
        return CGPoint(
            x: min(max(offset.x, 0), maxOffsetX),
            y: min(max(offset.y, 0), maxOffsetY)
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var state: CropState
        var imageView: UIImageView?
        var isApplyingState = false

        init(state: Binding<CropState>) {
            _state = state
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateState(from: scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateState(from: scrollView)
        }

        private func updateState(from scrollView: UIScrollView) {
            guard !isApplyingState else { return }
            state.zoomScale = scrollView.zoomScale
            state.contentOffset = scrollView.contentOffset
            state.hasUserAdjusted = true
        }
    }
}

private extension UIImage {
    func normalizedForCrop() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
