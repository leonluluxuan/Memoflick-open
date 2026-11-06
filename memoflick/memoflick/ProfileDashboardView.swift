import SwiftUI

struct ProfileStats {
    var clearedBytes: Int64
    var clearedItems: Int
    var treasuredCount: Int
    var organizedCount: Int

    var clearedSpaceLabel: String {
        Self.byteFormatter.string(fromByteCount: clearedBytes)
    }

    var treasuredLabel: String {
        NumberFormatter.localizedString(from: NSNumber(value: treasuredCount), number: .decimal)
    }

    var organizedLabel: String {
        NumberFormatter.localizedString(from: NSNumber(value: organizedCount), number: .decimal)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.includesUnit = true
        return formatter
    }()
}

struct ProfileDashboardView: View {
    var stats: ProfileStats
    var onShowTrash: () -> Void
    var onShowFavorites: () -> Void
    var onShowKept: () -> Void
    var onHelpFeedback: () -> Void
    var onAbout: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer

    private let cornerRadius: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsSection
                localModeSection
                moreSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(theme.contentBackground.ignoresSafeArea())
    }
}

private extension ProfileDashboardView {
    var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onShowTrash) {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#343C74"), Color(hex: "#151826")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1.2)
                                .frame(width: 130, height: 130)
                                .offset(x: -70, y: 60)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(localizer.text(.profileStatsCleared))
                                    .font(.system(size: 13, weight: .semibold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.white.opacity(0.8))
                                Text(stats.clearedSpaceLabel)
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.6)
                                Text(localizer.albumItemsCount(stats.clearedItems))
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }

                            Spacer()

                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Text(localizer.text(.profileStatsClearedHint))
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                statTile(
                    icon: "heart.fill",
                    iconColor: Color(hex: "#EC6CAB"),
                    value: stats.treasuredLabel,
                    title: localizer.text(.profileStatsMemories),
                    hint: localizer.text(.profileStatsMemoriesHint),
                    action: onShowFavorites
                )
                statTile(
                    icon: "film.fill",
                    iconColor: Color(hex: "#4DD0E1"),
                    value: stats.organizedLabel,
                    title: localizer.text(.profileStatsStories),
                    hint: localizer.text(.profileStatsStoriesHint),
                    action: onShowKept
                )
            }
        }
    }

    func statTile(
        icon: String,
        iconColor: Color,
        value: String,
        title: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .padding(10)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: cornerRadius * 0.6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius * 0.6, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var localModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizer.text(.profileAccountSectionTitle))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: "#6F86C9").opacity(0.16))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(hex: "#6F86C9"))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.language == .english ? "On-device mode" : "本机模式")
                        .font(.headline)
                    Text(localizer.language == .english ? "Your photos and progress stay on this device." : "照片和整理进度只保存在本机。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )
        }
    }

    var moreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.text(.profileMoreSectionTitle))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                settingsRow(
                    icon: "questionmark.bubble.fill",
                    tint: Color(hex: "#60A5FA"),
                    title: localizer.text(.profileMoreHelp),
                    action: onHelpFeedback
                )
                Divider()
                    .background(theme.dividerColor)
                settingsRow(
                    icon: "info.circle.fill",
                    tint: Color(hex: "#BA68C8"),
                    title: localizer.text(.profileMoreAbout),
                    trailingText: "v1.2.0",
                    action: onAbout
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )
        }
    }

    func settingsRow(
        icon: String,
        tint: Color,
        title: String,
        trailingText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.4), lineWidth: 1)
                    )
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
