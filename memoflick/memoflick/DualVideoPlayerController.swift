//
//  DualVideoPlayerController.swift
//  memoflick
//
//  Created by Codex on 2025/11/28.
//

import AVFoundation
import Combine
import Photos

@MainActor
final class DualVideoPlayerController: ObservableObject {
    @Published private(set) var currentPlayer: AVPlayer?
    @Published private(set) var isSwitching = false

    private let loader = VideoAssetLoader()
    private var standbyPlayer: AVPlayer?
    private var currentAssetID: String?
    private var standbyAssetID: String?
    private var loopObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var syncTask: Task<Void, Never>?

    func sync(current: PHAsset?, next: PHAsset?) {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            if Task.isCancelled { return }
            await self.prepareCurrent(with: current)
            if Task.isCancelled { return }
            await self.preloadNext(with: next)
        }
    }

    func pauseCurrentPlayback() {
        stop(player: currentPlayer)
    }

    func haltPlayback() {
        syncTask?.cancel()
        stop(player: currentPlayer)
        stop(player: standbyPlayer)
        currentPlayer = nil
        standbyPlayer = nil
        currentAssetID = nil
        standbyAssetID = nil
        isSwitching = false
    }
}

private extension DualVideoPlayerController {
    func prepareCurrent(with asset: PHAsset?) async {
        if Task.isCancelled { return }
        guard let asset else {
            haltPlayback()
            return
        }

        if standbyAssetID == asset.localIdentifier {
            await promoteStandbyToCurrent()
            await preloadNext(with: nil)
            return
        }

        guard currentAssetID != asset.localIdentifier else {
            currentPlayer?.play()
            return
        }

        isSwitching = true
        stop(player: currentPlayer)
        if let playerItem = await loader.playerItem(for: asset) {
            if Task.isCancelled { return }
            let player = AVPlayer(playerItem: playerItem)
            attachLoop(to: player)
            currentPlayer = player
            currentAssetID = asset.localIdentifier
            player.play()
            await waitForPlaybackReady(of: player)
        } else {
            currentPlayer = nil
            currentAssetID = nil
        }
        isSwitching = false
    }

    func preloadNext(with asset: PHAsset?) async {
        guard let asset else {
            stop(player: standbyPlayer)
            standbyPlayer = nil
            standbyAssetID = nil
            return
        }

        guard standbyAssetID != asset.localIdentifier,
              currentAssetID != asset.localIdentifier else { return }

        if Task.isCancelled { return }
        stop(player: standbyPlayer)
        if let playerItem = await loader.playerItem(for: asset) {
            if Task.isCancelled { return }
            let player = AVPlayer(playerItem: playerItem)
            attachLoop(to: player)
            player.pause()
            standbyPlayer = player
            standbyAssetID = asset.localIdentifier
        } else {
            standbyPlayer = nil
            standbyAssetID = nil
        }
    }

    func promoteStandbyToCurrent() async {
        guard let standbyPlayer else { return }
        isSwitching = true
        let previousPlayer = currentPlayer
        stop(player: previousPlayer)
        currentPlayer = standbyPlayer
        currentAssetID = standbyAssetID
        standbyAssetID = nil
        self.standbyPlayer = nil
        await currentPlayer?.seek(to: .zero)
        currentPlayer?.play()
        await waitForPlaybackReady(of: currentPlayer)
        isSwitching = false
    }

    func attachLoop(to player: AVPlayer) {
        guard let item = player.currentItem else { return }
        let id = ObjectIdentifier(player)
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        loopObservers[id] = token
    }

    func cleanupLoop(for player: AVPlayer?) {
        guard let player else { return }
        let id = ObjectIdentifier(player)
        if let token = loopObservers[id] {
            NotificationCenter.default.removeObserver(token)
            loopObservers.removeValue(forKey: id)
        }
    }

    func stop(player: AVPlayer?) {
        guard let player else { return }
        player.pause()
        player.seek(to: .zero)
        cleanupLoop(for: player)
    }

    func waitForPlaybackReady(of player: AVPlayer?) async {
        guard let player else { return }
        await waitUntilItemReady(player.currentItem)
        if player.currentItem?.status == .failed {
            return
        }
        if player.timeControlStatus == .playing {
            return
        }
        await waitUntilPlayerIsPlaying(player)
    }

    func waitUntilItemReady(_ item: AVPlayerItem?) async {
        guard let item else { return }
        let status = item.status
        if status == .readyToPlay || status == .failed {
            return
        }

        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            var resumed = false

            observation = item.observe(\.status, options: [.new]) { observedItem, _ in
                guard !resumed else { return }
                let newStatus = observedItem.status
                guard newStatus != .unknown else { return }
                resumed = true
                observation?.invalidate()
                observation = nil
                continuation.resume()
            }
        }
    }

    func waitUntilPlayerIsPlaying(_ player: AVPlayer) async {
        if player.timeControlStatus == .playing {
            return
        }

        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            var resumed = false

            let resumeIfNeeded: () -> Void = {
                guard !resumed else { return }
                resumed = true
                observation?.invalidate()
                observation = nil
                continuation.resume()
            }

            observation = player.observe(\.timeControlStatus, options: [.new]) { observedPlayer, _ in
                if observedPlayer.timeControlStatus == .playing {
                    resumeIfNeeded()
                } else if observedPlayer.timeControlStatus == .paused,
                          observedPlayer.currentItem?.status == .failed {
                    resumeIfNeeded()
                }
            }
        }
    }
}
