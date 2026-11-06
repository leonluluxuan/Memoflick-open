import SwiftUI

struct PhotoTutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let direction: PhotoTutorialDirection
}

enum PhotoTutorialDirection {
    case left
    case right
    case up
}

struct PhotoTutorialOverlay: View {
    let steps: [PhotoTutorialStep]
    var targetFrame: CGRect?
    @Binding var isVisible: Bool
    var onNext: () -> Void
    var onSkip: () -> Void
    var currentIndex: Int

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isVisible, !steps.isEmpty {
            GeometryReader { geometry in
                ZStack {
                    dimmedBackground(in: geometry)
                        .allowsHitTesting(false)

                    if let frame = paddedFrame(in: geometry) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 2)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .allowsHitTesting(false)
                    }

                    handLayer(in: geometry)
                        .allowsHitTesting(false)

                    VStack(spacing: 12) {
                        Spacer()
                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.22), value: currentIndex)
            }
            .transition(.opacity)
        }
    }
}

private extension PhotoTutorialOverlay {
    var currentStep: PhotoTutorialStep {
        steps[min(max(currentIndex, 0), steps.count - 1)]
    }

    func dimmedBackground(in geometry: GeometryProxy) -> some View {
        Color.black.opacity(0.6)
            .overlay {
                if let frame = paddedFrame(in: geometry) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .ignoresSafeArea()
    }

    func handLayer(in geometry: GeometryProxy) -> some View {
        let frame = paddedFrame(in: geometry) ?? defaultFrame(in: geometry)
        return VStack {
            PhotoTutorialHand(direction: currentStep.direction, reduceMotion: reduceMotion)
                .frame(width: 88, height: 88)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    var infoCard: some View {
        let step = currentStep
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(.title3.weight(.semibold))
                Text(step.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(primaryButtonTitle) {
                    onNext()
                }
                .buttonStyle(PrimaryTutorialButtonStyle())

                Button(localizerSkipText) {
                    onSkip()
                }
                .buttonStyle(SecondaryTutorialButtonStyle(theme: theme))
            }

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color(hex: "#6F86C9") : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16), radius: 24, x: 0, y: 14)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var primaryButtonTitle: String {
        currentIndex == steps.count - 1 ? Localization.text(.photoTutorialStart) : Localization.text(.photoTutorialNext)
    }

    var localizerSkipText: String {
        Localization.text(.photoTutorialSkip)
    }

    func paddedFrame(in geometry: GeometryProxy) -> CGRect? {
        guard let targetFrame else { return defaultFrame(in: geometry) }
        let inset: CGFloat = -14
        return targetFrame.insetBy(dx: inset, dy: inset)
    }

    func defaultFrame(in geometry: GeometryProxy) -> CGRect {
        let width = max(geometry.size.width - 80, 220)
        let height = min(geometry.size.height * 0.48, 440)
        let origin = CGPoint(
            x: (geometry.size.width - width) / 2,
            y: geometry.size.height * 0.16
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}

private struct PhotoTutorialHand: View {
    let direction: PhotoTutorialDirection
    let reduceMotion: Bool
    @State private var animate = false

    var body: some View {
        Image(systemName: "hand.point.up.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 64, height: 64)
            .foregroundColor(.white)
            .shadow(color: .white.opacity(0.6), radius: 10, x: 0, y: 0)
            .offset(animate ? targetOffset : startOffset)
            .rotationEffect(.degrees(animate ? rotation : 0))
            .opacity(animate ? 0 : 1)
            .onAppear(perform: start)
            .onChange(of: direction) { _ in
                animate = false
                DispatchQueue.main.async {
                    start()
                }
            }
    }

    private var startOffset: CGSize {
        CGSize(width: 18, height: 18)
    }

    private var targetOffset: CGSize {
        switch direction {
        case .left:
            return CGSize(width: -140, height: 0)
        case .right:
            return CGSize(width: 140, height: 0)
        case .up:
            return CGSize(width: 0, height: -180)
        }
    }

    private var rotation: Double {
        switch direction {
        case .left:
            return -14
        case .right:
            return 14
        case .up:
            return 0
        }
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
            animate = true
        }
    }
}

private struct PrimaryTutorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryTutorialButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.secondaryControlFill)
            )
            .foregroundColor(.primary)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
