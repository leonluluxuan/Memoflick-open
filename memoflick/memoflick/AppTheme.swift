//
//  AppTheme.swift
//  memoflick
//
//  Created by Codex on 2025/12/20.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func displayName(using localizer: AppLocalizer) -> String {
        switch self {
        case .system:
            return localizer.text(.themeSystemName)
        case .light:
            return localizer.text(.themeLightName)
        case .dark:
            return localizer.text(.themeDarkName)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .system:
            return .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var rootBackground: Color {
        switch self {
        case .system:
            return .white
        case .light:
            return .white
        case .dark:
            return Color(hex: "#050505")
        }
    }

    var elevatedBackground: Color {
        switch self {
        case .system:
            return .white
        case .light:
            return .white
        case .dark:
            return Color(hex: "#070707")
        }
    }

    var contentBackground: Color {
        switch self {
        case .system:
            return Color(hex: "#F4F5F9")
        case .light:
            return Color(hex: "#F4F5F9")
        case .dark:
            return Color(hex: "#0D0D10")
        }
    }

    var dividerColor: Color {
        switch self {
        case .system:
            return Color.black.opacity(0.05)
        case .light:
            return Color.black.opacity(0.05)
        case .dark:
            return Color.white.opacity(0.08)
        }
    }

    var gearButtonBackground: Color {
        switch self {
        case .system:
            return Color(.systemGray5)
        case .light:
            return Color(.systemGray5)
        case .dark:
            return Color.white.opacity(0.08)
        }
    }

    var gearButtonForeground: Color {
        switch self {
        case .system:
            return Color.secondary.opacity(0.8)
        case .light:
            return Color.secondary.opacity(0.8)
        case .dark:
            return Color.white.opacity(0.9)
        }
    }

    var brandLogoAssetName: String {
        switch self {
        case .system:
            return "BrandLogoLight"
        case .light:
            return "BrandLogoLight"
        case .dark:
            return "BrandLogoDark"
        }
    }

    var primaryControlFill: Color {
        switch self {
        case .system:
            return .white
        case .light:
            return .white
        case .dark:
            return Color(hex: "#151515")
        }
    }

    var secondaryControlFill: Color {
        switch self {
        case .system:
            return Color(hex: "#f7f7f7")
        case .light:
            return Color(hex: "#f7f7f7")
        case .dark:
            return Color.white.opacity(0.08)
        }
    }

    var folderCardBackground: Color {
        switch self {
        case .system:
            return .white
        case .light:
            return .white
        case .dark:
            return Color.white.opacity(0.06)
        }
    }

    var folderCardBorder: Color {
        switch self {
        case .system:
            return Color.black.opacity(0.04)
        case .light:
            return Color.black.opacity(0.04)
        case .dark:
            return Color.white.opacity(0.06)
        }
    }

    var mediaPlaceholderBackground: Color {
        switch self {
        case .system:
            return Color(.systemGray5)
        case .light:
            return Color(.systemGray5)
        case .dark:
            return Color.white.opacity(0.08)
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
