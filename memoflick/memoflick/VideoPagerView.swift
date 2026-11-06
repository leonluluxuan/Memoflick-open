//
//  VideoPagerView.swift
//  memoflick
//
//  Created by Codex on 2025/02/15.
//

import SwiftUI

@available(iOS 17.0, *)
struct VideoPagerView<Previous: View, Current: View, Next: View>: View {
    let previous: Previous
    let current: Current
    let next: Next
    let isPreviousEnabled: Bool
    let isNextEnabled: Bool
    var onPageSettled: (NavigationSwipe) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isTransitioning = false
    @State private var pendingDirection: NavigationSwipe?
    @State private var settleWorkItem: DispatchWorkItem?

    private let settleAnimation = Animation.interactiveSpring(response: 0.45, dampingFraction: 0.92)
    private let bounceAnimation = Animation.spring(response: 0.4, dampingFraction: 0.88)

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack {
                previousCard(height: height)
                nextCard(height: height)
                currentCard(height: height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(height: height))
            .onDisappear {
                cancelPendingSettle(resetOffset: true)
            }
        }
    }
}

@available(iOS 17.0, *)
private extension VideoPagerView {
    func dragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                guard !isTransitioning else { return }
                let raw = value.translation.height
                dragOffset = adjustedOffset(for: raw, height: height)
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                cancelPendingSettle()
                settleDrag(value: value, height: height)
            }
    }

    func adjustedOffset(for translation: CGFloat, height: CGFloat) -> CGFloat {
        if translation > 0 && !isPreviousEnabled {
            return rubberBand(for: translation)
        } else if translation < 0 && !isNextEnabled {
            return -rubberBand(for: -translation)
        }
        return translation
    }

    func rubberBand(for value: CGFloat) -> CGFloat {
        let constant: CGFloat = 0.55
        let dimension: CGFloat = 180
        return (constant * abs(value) * dimension) / (abs(value) + constant * dimension)
            * (value >= 0 ? 1 : -1)
    }

    func settleDrag(value: DragGesture.Value, height: CGFloat) {
        let threshold = height * 0.12
        let flickThreshold: CGFloat = 90
        let offset = dragOffset
        let predicted = value.predictedEndTranslation.height
        let direction: NavigationSwipe?

        if shouldTriggerNext(offset: offset, predicted: predicted, threshold: threshold, flickThreshold: flickThreshold) {
            direction = .next
        } else if shouldTriggerPrevious(offset: offset, predicted: predicted, threshold: threshold, flickThreshold: flickThreshold) {
            direction = .previous
        } else {
            direction = nil
        }

        guard let direction else {
            withAnimation(bounceAnimation) {
                dragOffset = 0
            }
            return
        }

        isTransitioning = true
        pendingDirection = direction
        let target = direction == .next ? -height : height

        withAnimation(settleAnimation) {
            dragOffset = target
        }

        let workItem = DispatchWorkItem {
            guard pendingDirection == direction else { return }
            pendingDirection = nil
            isTransitioning = false

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragOffset = 0
                onPageSettled(direction)
            }
        }
        settleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    func shouldTriggerNext(offset: CGFloat, predicted: CGFloat, threshold: CGFloat, flickThreshold: CGFloat) -> Bool {
        guard isNextEnabled else { return false }
        return offset <= -threshold || predicted <= -flickThreshold
    }

    func shouldTriggerPrevious(offset: CGFloat, predicted: CGFloat, threshold: CGFloat, flickThreshold: CGFloat) -> Bool {
        guard isPreviousEnabled else { return false }
        return offset >= threshold || predicted >= flickThreshold
    }

    func currentProgress(height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return min(abs(dragOffset) / height, 1)
    }

    func currentCard(height: CGFloat) -> some View {
        current
            .offset(y: dragOffset)
    }

    func previousCard(height: CGFloat) -> some View {
        let incomingOffset = max(dragOffset, 0)
        return previous
            .offset(y: -height + incomingOffset)
            .opacity(isPreviousEnabled ? 1 : 0)
    }

    func nextCard(height: CGFloat) -> some View {
        let incomingOffset = min(dragOffset, 0)
        return next
            .offset(y: height + incomingOffset)
            .opacity(isNextEnabled ? 1 : 0)
    }

    func cancelPendingSettle(resetOffset: Bool = false) {
        settleWorkItem?.cancel()
        settleWorkItem = nil
        pendingDirection = nil
        isTransitioning = false
        if resetOffset {
            dragOffset = 0
        }
    }
}
