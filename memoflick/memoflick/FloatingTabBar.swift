//
//  FloatingTabBar.swift
//  memoflick
//
//  Created by Codex on 2026/01/08.
//

import SwiftUI

/// 悬浮玻璃质感底栏，统一背景与按钮配色。
struct FloatingTabBar: View {
    @Binding var selectedTab: MainTab
    let theme: AppTheme
    let localizer: AppLocalizer
    let safeAreaInsets: EdgeInsets
    let customWidth: CGFloat?
    let barHeight: CGFloat
    let widthScale: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animationNamespace

    init(
        selectedTab: Binding<MainTab>,
        theme: AppTheme,
        localizer: AppLocalizer,
        safeAreaInsets: EdgeInsets,
        customWidth: CGFloat? = nil,
        barHeight: CGFloat = 50,
        widthScale: CGFloat = 0.93
    ) {
        _selectedTab = selectedTab
        self.theme = theme
        self.localizer = localizer
        self.safeAreaInsets = safeAreaInsets
        self.customWidth = customWidth
        self.barHeight = barHeight
        self.widthScale = widthScale
    }

    private struct TabItem: Identifiable {
        let id = UUID()
        let tab: MainTab
        let icon: String
        let title: String
    }

    private var tabs: [TabItem] {
        [
            TabItem(tab: .photo, icon: "square.stack.3d.up.fill", title: localizer.text(.tabPhotos)),
            TabItem(tab: .video, icon: "play.rectangle.fill", title: localizer.text(.tabVideos)),
            TabItem(tab: .album, icon: "photo.on.rectangle.angled", title: localizer.text(.tabAlbum)),
            TabItem(tab: .profile, icon: "person.crop.circle", title: localizer.text(.tabProfile))
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { item in
                tabButton(for: item)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
        .background {
            ZStack {
                Rectangle()
                    .fill(backgroundMaterial)

                Rectangle()
                    .fill(backgroundTint)
            }
            .clipShape(Capsule())
            .shadow(
                color: shadowColor,
                radius: 14,
                x: 0,
                y: 6
            )
        }
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [borderTop, borderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .frame(width: resolvedWidth, height: barHeight)
        .padding(.horizontal, outerHorizontalPadding)
    }
}

private extension FloatingTabBar {
    private func tabButton(for item: TabItem) -> some View {
        let isSelected = selectedTab == item.tab
        let palette = palette(for: item.tab)

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedTab = item.tab
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(palette.selectionBackground)
                        .matchedGeometryEffect(id: "tab_bg", in: animationNamespace)
                        .frame(width: 52, height: 44)
                        .shadow(color: palette.selectionShadow, radius: 9, x: 0, y: 3)
                }

                VStack(spacing: 3) {
                    Image(systemName: item.icon)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? palette.iconActive : palette.iconInactive)
                        .offset(y: 0)
                        .shadow(color: palette.iconGlow, radius: isSelected ? 5 : 0, x: 0, y: 0)

                    if isSelected {
                        Text(item.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(palette.textActive)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .offset(y: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(TabBarScaleButtonStyle())
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(isSelected ? Text("Selected") : Text(""))
    }

    var horizontalPadding: CGFloat {
        // 适配大屏留白
        UIScreen.main.bounds.width > 820 ? 12 : 6
    }

    var outerHorizontalPadding: CGFloat { 0 }

    var resolvedWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return customWidth ?? screenWidth * widthScale
    }

    var isDarkSurface: Bool {
        // 浅色模式下点击视频 Tab，底栏切换为深色风格
        colorScheme == .light && selectedTab == .video
    }

    var backgroundMaterial: some ShapeStyle {
        if isDarkSurface {
            return AnyShapeStyle(Color.black.opacity(0.7))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    var backgroundTint: Color {
        if isDarkSurface {
            return Color.black.opacity(0.35)
        }
        return colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.3)
    }

    var shadowColor: Color {
        if isDarkSurface {
            return Color.black.opacity(0.55)
        }
        return colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.12)
    }

    var borderTop: Color {
        Color.white.opacity((isDarkSurface || colorScheme == .dark) ? 0.22 : 0.5)
    }

    var borderBottom: Color {
        Color.white.opacity(0.08)
    }

    struct Palette {
        let iconActive: Color
        let iconInactive: Color
        let textActive: Color
        let selectionBackground: Color
        let selectionShadow: Color
        let iconGlow: Color
    }

    func palette(for tab: MainTab) -> Palette {
        let effectiveScheme: ColorScheme = isDarkSurface ? .dark : colorScheme
        let accent = theme == .dark ? Color(hex: "#6F86C9") : Color(hex: "#5E7BD7")
        let inactive = Color.gray.opacity(effectiveScheme == .dark ? 0.55 : 0.7)
        let selectionBg = effectiveScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)

        return Palette(
            iconActive: accent,
            iconInactive: inactive,
            textActive: accent,
            selectionBackground: selectionBg,
            selectionShadow: accent.opacity(0.3),
            iconGlow: effectiveScheme == .dark ? Color.white.opacity(0.25) : Color.clear
        )
    }
}

/// 轻微缩放的按压反馈。
struct TabBarScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}
