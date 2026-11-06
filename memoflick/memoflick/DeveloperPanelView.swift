//
//  DeveloperPanelView.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

#if DEV_PANEL
import SwiftUI
import PhotosUI
import Photos
import UIKit

struct DeveloperPanelView: View {
    @Binding var settings: DeveloperSettings
    let onImportAssets: (_ identifiers: [String], _ testImages: [UIImage]) -> Void
    let onForceLogout: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingForceLogoutConfirm = false
    @Environment(\.localizer) private var localizer

    var body: some View {
        NavigationStack {
            Form {
                Section(localizer.text(.developerTipsSectionTitle)) {
                    Text(localizer.text(.developerTipsMessage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                Section(localizer.text(.developerThemeSectionTitle)) {
                    Picker(localizer.text(.developerThemePickerLabel), selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName(using: localizer)).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(localizer.text(.developerLanguageSectionTitle)) {
                    Picker(localizer.text(.developerLanguagePickerLabel), selection: languageOverrideBinding) {
                        Text(localizer.text(.developerLanguageAutoOption))
                            .tag(LanguageOverrideOption.automatic)
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.nativeName)
                                .tag(LanguageOverrideOption.manual(language))
                        }
                    }
                }

                Section(localizer.text(.developerMockLoginTitle)) {
                    Toggle(isOn: $settings.simulateLoggedIn) {
                        Text(localizer.text(.developerMockLoginToggleLabel))
                    }

                    Text(localizer.text(.developerMockLoginDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Section(localizer.text(.developerPremiumSectionTitle)) {
                    Picker(localizer.text(.developerPremiumPickerLabel), selection: $settings.premiumOverride) {
                        ForEach(PremiumOverride.allCases) { override in
                            Text(override.displayName(using: localizer))
                                .tag(override)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(localizer.text(.developerPremiumDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Section(localizer.text(.developerAccountSectionTitle)) {
                    Button(role: .destructive) {
                        isShowingForceLogoutConfirm = true
                    } label: {
                        Label(localizer.text(.developerForceLogoutButton), systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Text(localizer.text(.developerForceLogoutDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Section(localizer.text(.developerTestToolsSectionTitle)) {
                    PhotosPicker(selection: $pickerItems, matching: .images) {
                        Label(localizer.text(.developerUploadTestPhotos), systemImage: "tray.and.arrow.up")
                    }
                    .labelStyle(.titleAndIcon)
                    Toggle("启用模拟日期", isOn: Binding(
                        get: { settings.simulatedDate != nil },
                        set: { enabled in
                            settings.simulatedDate = enabled ? (settings.simulatedDate ?? Date()) : nil
                        }
                    ))
                    DatePicker(
                        "模拟今日日期",
                        selection: Binding(
                            get: { settings.simulatedDate ?? Date() },
                            set: { newValue in settings.simulatedDate = newValue }
                        ),
                        displayedComponents: .date
                    )
                    .disabled(settings.simulatedDate == nil)
                    Button("清除模拟日期") {
                        settings.simulatedDate = nil
                    }
                }
            }
            .navigationTitle(localizer.text(.developerNavigationTitle))
            .alert(localizer.text(.developerForceLogoutConfirmTitle), isPresented: $isShowingForceLogoutConfirm) {
                Button(localizer.text(.actionCancel), role: .cancel) {}
                Button(localizer.text(.actionConfirm), role: .destructive) {
                    onForceLogout()
                }
            } message: {
                Text(localizer.text(.developerForceLogoutConfirmMessage))
            }
            .onChange(of: pickerItems) { newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var identifiers: [String] = []
                    var importedImages: [UIImage] = []

                    for item in newItems {
                        if let identifier = item.itemIdentifier {
                            identifiers.append(identifier)
                            continue
                        }

                        guard let image = await loadImage(from: item) else { continue }

                        if let identifier = await saveImageToLibrary(image) {
                            identifiers.append(identifier)
                        } else {
                            importedImages.append(image)
                        }
                    }

                    if !identifiers.isEmpty || !importedImages.isEmpty {
                        await MainActor.run {
                            onImportAssets(identifiers, importedImages)
                        }
                    }

                    await MainActor.run {
                        pickerItems.removeAll()
                    }
                }
            }
        }
    }
}

private extension DeveloperPanelView {
    enum LanguageOverrideOption: Hashable, Identifiable {
        case automatic
        case manual(AppLanguage)

        var id: String {
            switch self {
            case .automatic:
                return "automatic"
            case let .manual(language):
                return "manual_\(language.rawValue)"
            }
        }
    }

    var languageOverrideBinding: Binding<LanguageOverrideOption> {
        Binding(
            get: {
                if let override = settings.languageOverride {
                    return .manual(override)
                }
                return .automatic
            },
            set: { newValue in
                switch newValue {
                case .automatic:
                    settings.languageOverride = nil
                case let .manual(language):
                    settings.languageOverride = language
                }
            }
        )
    }
}

private extension DeveloperPanelView {
    func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    func saveImageToLibrary(_ image: UIImage) async -> String? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            var identifier: String?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                identifier = request.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                if success, let identifier {
                    continuation.resume(returning: identifier)
                } else {
                    if let error {
                        print("Failed to save imported photo:", error)
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
#endif
