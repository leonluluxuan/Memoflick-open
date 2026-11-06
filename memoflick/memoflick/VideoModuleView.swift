//
//  VideoModuleView.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import Photos
import Combine

@available(iOS 17.0, *)
struct VideoModuleView: View {
    @ObservedObject var viewModel: VideoReviewViewModel
    var bottomPadding: CGFloat
    var onFavoriteRequested: (VideoReviewItem) -> Void
    var onReviewDeleted: () -> Void
    @StateObject private var playerController = DualVideoPlayerController()
    @AppStorage("hasSeenVideoTutorial") private var hasSeenVideoTutorial = false
    @State private var sharePayload: VideoSharePayload?
    @State private var exportedShareURL: URL?
    @State private var isExporting = false
    @State private var isPlaying = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isScrubbing = false
    @State private var showPauseBadge = false
    @State private var timeObserver: Any?
    @State private var observedPlayer: AVPlayer?
    @State private var bottomOverlayHeight: CGFloat = 0
    @State private var nextPreviewImage: UIImage?
    @State private var previousPreviewImage: UIImage?
    @State private var currentPreviewImage: UIImage?
    @State private var previewCache: [String: UIImage] = [:]
    @State private var transitionPhase: VideoTransitionPhase = .idle
    @State private var currentAspectRatio: CGFloat = 16.0 / 9.0
    @State private var showTutorial = false
    @State private var wasPlayingBeforeTutorial = true
    @Environment(\.localizer) private var localizer

    private let thumbnailProvider = VideoThumbnailProvider()

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            content
                .ignoresSafeArea()
                .disabled(showTutorial)
                .blur(radius: showTutorial ? 2 : 0)
                .overlay {
                    if showTutorial {
                        VideoTutorialOverlay(
                            localizer: localizer,
                            onDone: {
                                configureAudioSessionForPlayback()
                                dismissTutorial()
                            }
                        )
                        .transition(.opacity)
                    }
                }

            if viewModel.isScanning && viewModel.hasInitialBatchReady {
                VideoScanProgressView(progress: viewModel.scanProgress)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

        }
        .sheet(item: $sharePayload, onDismiss: cleanupShareFile) { payload in
            ShareSheetView(activityItems: payload.items)
        }
        .task(id: syncToken) {
            syncPlayers()
        }
        .task(id: previewToken) {
            await loadPreviewImages()
        }
        .onReceive(playerController.$currentPlayer) { player in
            configurePlayerTracking(for: player)
        }
        .onDisappear {
            tearDownTimeObserver()
        }
        .task {
            await checkTutorialIfNeeded()
        }
        .onChange(of: viewModel.currentVideo?.id) { _ in
            Task { await checkTutorialIfNeeded() }
        }
    }
}

@available(iOS 17.0, *)
private extension VideoModuleView {
    var content: some View {
        Group {
            if isAccessDenied {
                PermissionDeniedView(openSettingsAction: openSettings)
                    .padding(.horizontal, 24)
            } else if viewModel.isScanning && !viewModel.hasInitialBatchReady {
                VideoScanningPlaceholder()
            } else if let current = viewModel.currentVideo {
                playingView(for: current)
            } else if viewModel.isUsingTimeFilter {
                FilteredVideoEmptyView(onResetRandom: {
                    viewModel.resetTimeFilterToAll()
                })
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VideoEmptyPlaceholder(onRefresh: {
                    Task { await viewModel.refreshIfNeeded() }
                })
            }
        }
    }

    func playingView(for item: VideoReviewItem) -> some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let containerSize = proxy.size

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                videoPager(
                    current: item,
                    containerSize: containerSize,
                    safeTop: safeTop,
                    safeBottom: safeBottom
                )
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            togglePlayback()
                        }
                )

                if showPauseBadge {
                    PauseBadge()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, safeTop)
                        .padding(.bottom, safeBottom)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    bottomOverlay(for: item, safeBottom: safeBottom)
                }
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()
                    controlColumn
                        .padding(.trailing, 20)
                        .padding(.bottom, bottomPadding + bottomOverlayHeight + 25)
                        .offset(y: -40)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .onPreferenceChange(BottomOverlayHeightPreference.self) { value in
                if value > 0 {
                    bottomOverlayHeight = value
                }
            }
        }
    }

    func videoPager(
        current item: VideoReviewItem,
        containerSize: CGSize,
        safeTop: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        return VideoPagerView(
            previous: pagerCard(for: viewModel.previousVideo, role: .previous),
            current: pagerCard(for: item, role: .current),
            next: pagerCard(for: viewModel.nextVideo, role: .next),
            isPreviousEnabled: viewModel.hasPreviousVideo,
            isNextEnabled: viewModel.hasNextVideo,
            onPageSettled: handlePagerSwipe
        )
        .frame(width: containerSize.width, height: containerSize.height)
        .padding(.top, -safeTop - 18)
        .padding(.bottom, -max(safeBottom, 8))
        .ignoresSafeArea()
    }

    @ViewBuilder
    func pagerCard(
        for item: VideoReviewItem?,
        role: VideoCardRole
    ) -> some View {
        Group {
            switch role {
            case .current:
                VideoPlayerSurfaceView(player: playerController.currentPlayer)
                    .allowsHitTesting(false)
            case .next, .previous:
                if let image = previewImage(for: role) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if item != nil {
                    Color.black.opacity(0.5)
                        .overlay(
                            Image(systemName: "video")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.35))
                        )
                } else {
                    Color.clear
                }
            }
        }
        .allowsHitTesting(role == .current)
        .opacity(item == nil && role != .current ? 0 : 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    func previewImage(for role: VideoCardRole) -> UIImage? {
        switch role {
        case .current:
            return currentPreviewImage
        case .next:
            return nextPreviewImage
        case .previous:
            return previousPreviewImage
        }
    }

    func handlePagerSwipe(_ direction: NavigationSwipe) {
        transitionPhase = .covering
        let didMove: Bool
        switch direction {
        case .next:
            if let image = nextPreviewImage {
                currentPreviewImage = image
            }
            if let nextItem = viewModel.nextVideo {
                currentAspectRatio = nextItem.aspectRatio
            }
            didMove = viewModel.advanceToNextVideo()
        case .previous:
            if let image = previousPreviewImage {
                currentPreviewImage = image
            }
            if let previousItem = viewModel.previousVideo {
                currentAspectRatio = previousItem.aspectRatio
            }
            didMove = viewModel.showPreviousVideo()
        }
        if !didMove {
            transitionPhase = .idle
        }
        showPauseBadge = false
    }

    func bottomOverlay(for item: VideoReviewItem, safeBottom: CGFloat) -> some View {
        return VStack(spacing: 12) {
            dateRibbon(for: item)
            progressPanel
                .offset(y: -10) // 时间轴整体上移 10pt
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, max(safeBottom - 2, 0))
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(1.0),
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .padding(.bottom, -10)
        )
        .offset(y: safeBottom > 0 ? 0 : -8)
        .ignoresSafeArea(edges: .bottom)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: BottomOverlayHeightPreference.self, value: proxy.size.height)
            }
        )
    }

    func dateRibbon(for item: VideoReviewItem) -> some View {
        HStack {
            Text(item.displayDate)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())
            Spacer()
        }
    }

    var progressPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        currentTime = newValue
                    }
                ),
                in: 0...max(duration, 0.1),
                onEditingChanged: handleSliderEditing
            )
            .tint(.white)

            HStack {
                Text(formattedTime(currentTime))
                Spacer()
                Text(formattedTime(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    var controlColumn: some View {
        VStack(spacing: 10) {
            VideoActionButton(
                icon: "star.fill",
                title: localizer.text(.actionFavorite),
                tint: Color(hex: "#FFCE61")
            ) {
                if let current = viewModel.currentVideo {
                    onFavoriteRequested(current)
                }
            }
            VideoActionButton(
                icon: "trash.fill",
                title: localizer.text(.actionDelete),
                tint: Color(hex: "#FF5D73")
            ) {
                viewModel.deleteCurrent()
            }
            VideoActionButton(
                icon: "arrowshape.turn.up.right.fill",
                title: localizer.text(.actionShare),
                tint: Color(hex: "#7DD6FF")
            ) {
                performShareAction()
            }
            .disabled(isExporting)
            .overlay(alignment: .top) {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded { })
    }

    var isAccessDenied: Bool {
        let status = viewModel.authorizationStatus
        return status == .denied || status == .restricted
    }

    var currentPlayerIsReady: Bool {
        playerController.currentPlayer?.currentItem != nil
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func shareCurrent() async -> URL? {
        await viewModel.exportCurrentVideo()
    }

    func cleanupShareFile() {
        if let url = exportedShareURL {
            try? FileManager.default.removeItem(at: url)
            exportedShareURL = nil
        }
        sharePayload = nil
    }

    func checkTutorialIfNeeded() async {
        guard !hasSeenVideoTutorial else { return }
        guard viewModel.currentVideo != nil else { return }
        await MainActor.run {
            guard !showTutorial else { return }
            wasPlayingBeforeTutorial = isPlaying
            pausePlaybackForAction()
            withAnimation(.easeInOut(duration: 0.25)) {
                showTutorial = true
            }
        }
    }

    func dismissTutorial() {
        hasSeenVideoTutorial = true
        withAnimation(.easeInOut(duration: 0.25)) {
            showTutorial = false
        }
        if wasPlayingBeforeTutorial {
            playerController.currentPlayer?.play()
            isPlaying = true
        }
    }

    func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func syncPlayers() {
        playerController.sync(
            current: viewModel.currentVideo?.asset,
            next: viewModel.nextVideo?.asset
        )
    }

    @MainActor
    func loadPreviewImages() async {
        async let currentTask: () = assignPreview(for: viewModel.currentVideo, slot: .current)
        async let nextTask: () = assignPreview(for: viewModel.nextVideo, slot: .next)
        async let previousTask: () = assignPreview(for: viewModel.previousVideo, slot: .previous)
        _ = await (currentTask, nextTask, previousTask)
    }

    func handleSliderEditing(_ editing: Bool) {
        isScrubbing = editing
        if !editing {
            seek(to: currentTime)
        }
    }

    func seek(to time: Double) {
        guard let player = playerController.currentPlayer else { return }
        let clamped = min(max(time, 0), duration)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        if isPlaying {
            player.play()
        }
    }

    func togglePlayback() {
        guard let player = playerController.currentPlayer else { return }
        let isCurrentlyPlaying = player.timeControlStatus == .playing || player.rate > 0
        if isCurrentlyPlaying {
            player.pause()
            isPlaying = false
            showPauseBadge = true
        } else {
            player.play()
            isPlaying = true
            showPauseBadge = false
        }
    }

    func configurePlayerTracking(for player: AVPlayer?) {
        tearDownTimeObserver()
        observedPlayer = player
        guard let player else {
            currentTime = 0
            duration = 1
            isPlaying = false
            showPauseBadge = false
            if transitionPhase != .idle {
                withAnimation(.easeInOut(duration: 0.08)) {
                    transitionPhase = .idle
                }
            }
            return
        }
        duration = player.currentItem?.duration.seconds.validDuration ?? 0
        if duration <= 0 { duration = 1 }
        currentTime = player.currentTime().seconds.validDuration
        let isCurrentlyPlaying = player.timeControlStatus == .playing || player.rate > 0
        isPlaying = isCurrentlyPlaying
        if isCurrentlyPlaying {
            showPauseBadge = false
        }
        let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isScrubbing {
                currentTime = time.seconds.validDuration
            }
        }

        if transitionPhase != .idle {
            withAnimation(.easeInOut(duration: 0.08)) {
                transitionPhase = .idle
            }
        }
    }

    func tearDownTimeObserver() {
        if let token = timeObserver, let player = observedPlayer {
            player.removeTimeObserver(token)
        }
        timeObserver = nil
        observedPlayer = nil
    }

    func pausePlaybackForAction() {
        playerController.pauseCurrentPlayback()
        isPlaying = false
        showPauseBadge = false
    }

    func performShareAction() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            let url = await shareCurrent()
            await MainActor.run {
                if let url {
                    exportedShareURL = url
                    sharePayload = VideoSharePayload(items: [VideoShareItemSource(url: url)])
                }
                isExporting = false
            }
        }
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(Int(seconds.rounded()), 0)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

@available(iOS 17.0, *)
private extension VideoModuleView {
    var syncToken: String {
        let currentID = viewModel.currentVideo?.id ?? "nil"
        let nextID = viewModel.nextVideo?.id ?? "nil"
        return "\(currentID)-\(nextID)"
    }

    var previewToken: String {
        let currentID = viewModel.currentVideo?.id ?? "nil"
        let nextID = viewModel.nextVideo?.id ?? "nil"
        let previousID = viewModel.previousVideo?.id ?? "nil"
        return "\(currentID)-\(nextID)-\(previousID)"
    }

    var shouldShowOverlay: Bool {
        transitionPhase != .idle
    }

    enum PreviewSlot {
        case current
        case next
        case previous
    }

    enum VideoTransitionPhase {
        case idle
        case covering
    }

    func videoContentRect(container: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard container.width > 0, container.height > 0 else { return CGRect(origin: .zero, size: container) }
        let targetAspect: CGFloat = aspectRatio
        let containerAspect = container.height / container.width

        var width = container.width
        var height = container.height

        if containerAspect > targetAspect {
            height = container.width * targetAspect
        } else {
            width = container.height / targetAspect
        }

        let originX = (container.width - width) / 2
        let originY = (container.height - height) / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    func assignPreview(for item: VideoReviewItem?, slot: PreviewSlot) async {
        guard let item else {
            updatePreview(nil, for: slot)
            return
        }

        let id = item.id
        updateAspectIfNeeded(slot: slot, item: item)

        if let cached = previewCache[id] {
            updatePreview(cached, for: slot)
            return
        }

        if let image = await thumbnailProvider.firstFrameImage(for: item.asset) {
            previewCache[id] = image
            if slotMatchesCurrentContext(slot: slot, id: id) {
                updatePreview(image, for: slot)
            }
        }
    }

    func updatePreview(_ image: UIImage?, for slot: PreviewSlot) {
        switch slot {
        case .current:
            currentPreviewImage = image
        case .next:
            nextPreviewImage = image
        case .previous:
            previousPreviewImage = image
        }
    }

    func updateAspectIfNeeded(slot: PreviewSlot, item: VideoReviewItem) {
        guard slot == .current else { return }
        currentAspectRatio = item.aspectRatio
    }

    func slotMatchesCurrentContext(slot: PreviewSlot, id: String) -> Bool {
        switch slot {
        case .current:
            return viewModel.currentVideo?.id == id
        case .next:
            return viewModel.nextVideo?.id == id
        case .previous:
            return viewModel.previousVideo?.id == id
        }
    }
}

@available(iOS 17.0, *)
private struct FilteredVideoEmptyView: View {
    var onResetRandom: () -> Void
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(localizer.text(.videoTimeFilterEmptyTitle))
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Text(localizer.text(.videoTimeFilterEmptySubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button(localizer.text(.actionSwitchToRandom)) {
                onResetRandom()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

private enum VideoCardRole {
    case previous
    case current
    case next
}

private extension Double {
    var validDuration: Double {
        guard self.isFinite else { return 0 }
        return self
    }
}

private struct VideoActionButton: View {
    let icon: String
    let title: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0.8) {
                Image(systemName: icon)
                    .font(.system(size: 24.3, weight: .semibold))
                    .frame(width: 52.4, height: 52.4)
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct VideoSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private final class VideoShareItemSource: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }
}

private struct PauseBadge: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(.white)
            .padding(32)
            .background(Color.black.opacity(0.45), in: Circle())
    }
}

private struct VideoTutorialOverlay: View {
    var localizer: AppLocalizer
    var onDone: () -> Void
    @State private var swipeOffset: CGFloat = -22

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 36) {
                SwipeGestureShowcase(
                    swipeOffset: $swipeOffset,
                    swipeUpText: localizer.text(.videoTutorialSwipeUp),
                    swipeDownText: localizer.text(.videoTutorialSwipeDown)
                )
                ControlHintsStrip(localizer: localizer)
                Button(action: onDone) {
                    Text(localizer.text(.videoTutorialGotIt))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Color.white, in: Capsule())
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                swipeOffset = 22
            }
        }
    }
}

private struct SwipeGestureShowcase: View {
    @Binding var swipeOffset: CGFloat
    var swipeUpText: String
    var swipeDownText: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 220, height: 360)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: "hand.draw")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .offset(y: swipeOffset)
                    .animation(.easeInOut(duration: 1.4), value: swipeOffset)

                VStack {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .offset(y: swipeOffset)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .offset(y: -swipeOffset)
                }
                .frame(height: 260)
            }

            VStack(spacing: 8) {
                Text(swipeUpText)
                Text(swipeDownText)
            }
            .font(.headline)
            .foregroundStyle(.white)
        }
    }
}

private struct ControlHintsStrip: View {
    var localizer: AppLocalizer

    var body: some View {
        VStack(spacing: 12) {
            Text(localizer.text(.videoTutorialControlsTitle))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 12) {
                ControlHintCard(
                    icon: "star.fill",
                    title: localizer.text(.actionFavorite),
                    detail: localizer.text(.videoTutorialFavoriteDetail)
                )
                ControlHintCard(
                    icon: "trash.fill",
                    title: localizer.text(.actionDelete),
                    detail: localizer.text(.videoTutorialDeleteDetail)
                )
                ControlHintCard(
                    icon: "arrowshape.turn.up.right.fill",
                    title: localizer.text(.actionShare),
                    detail: localizer.text(.videoTutorialShareDetail)
                )
            }
        }
    }
}

private struct ControlHintCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct VideoScanningPlaceholder: View {
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
            Text(localizer.text(.videoScanPlaceholderTitle))
                .font(.headline)
                .foregroundStyle(.white)
            Text(localizer.text(.videoScanPlaceholderMessage))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }
}

private struct VideoEmptyPlaceholder: View {
    var onRefresh: () -> Void
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.8))
            Text(localizer.text(.videoEmptyTitle))
                .font(.headline)
                .foregroundStyle(.white)
            Text(localizer.text(.videoEmptyMessage))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(localizer.text(.actionRescan)) {
                onRefresh()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct VideoScanProgressView: View {
    var progress: Double
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(localizer.text(.videoScanBackgroundTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            ProgressView(value: progress)
                .tint(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
    }
}

enum NavigationSwipe {
    case next
    case previous
}

private struct BottomOverlayHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct VideoThumbnailProvider {
    private let imageManager = PHCachingImageManager()
    private let imageOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        return options
    }()

    func firstFrameImage(for asset: PHAsset, targetSize: CGSize = CGSize(width: 720, height: 1280)) async -> UIImage? {
        await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: imageOptions
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
