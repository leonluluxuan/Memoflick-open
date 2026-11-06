import SwiftUI
import PhotosUI
import UIKit
import WidgetKit

struct CompactSettingsView: View {
    @Binding var settings: DeveloperSettings
    @Binding var userSettings: UserSettings
    @Binding var photoWallSettings: PhotoWallSettings
    var availableMonths: [YearMonth: Int]
    var isMonthListLoading: Bool
    var scrollToPhotoWall: Bool = false
    var onScrollToPhotoWallHandled: (() -> Void)?
    var onReplayTutorial: (() -> Void)?
    var onSelectPhotoWallDaily: (() -> Void)?
    var onSelectPhotoWallRandomOnce: (() -> Void)?
    var onSelectPhotoWallManual: ((_ identifiers: [String]) -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer
    @State private var isShowingMonthFilter = false
    @State private var activePhotoWallOption: PhotoWallOption?
    @State private var isShowingManualPicker = false
    @State private var isShowingBackgroundPicker = false
    @State private var manualSelectionError: String?
    @State private var backgroundSelectionError: String?
    @State private var pendingBackgroundImage: UIImage?
    @State private var isShowingBackgroundCropper = false
    @State private var isRefreshExpanded = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleIconSize: CGFloat = 34
    private let photoWallSectionID = "photo-wall-management-section"

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    settingsHeader
                    ScrollViewReader { proxy in
                        Form {
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
                                    Text(localizer.text(.developerLanguageAutoOption)).tag(AppLanguage?.none)
                                    ForEach(AppLanguage.allCases) { language in
                                        Text(language.nativeName).tag(AppLanguage?.some(language))
                                    }
                                }
                            }

                            Section(localizer.text(.timeFilterSettingsSectionTitle)) {
                                Button {
                                    isShowingMonthFilter = true
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(localizer.text(.timeFilterEntryTitle))
                                                .font(.body.weight(.medium))
                                            Text(timeFilterSummary)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            Section(localizer.text(.photoTutorialSettingsSectionTitle)) {
                                Button(localizer.text(.photoTutorialReplayButton)) {
                                    userSettings.hasSeenPhotoTutorial = false
                                    onReplayTutorial?()
                                }
                            }

                            Section(localizer.text(.photoWallSettingsSectionTitle)) {
                                photoWallOptionRow(
                                    title: localizer.text(.photoWallOptionBackground),
                                    subtitle: nil,
                                    trailingValue: photoWallBackgroundSubtitle,
                                    action: { activePhotoWallOption = .customBackground }
                                )
                                photoWallOptionRow(
                                    title: localizer.text(.photoWallCustomRefreshTitle),
                                    subtitle: nil,
                                    trailingIconRotation: isRefreshExpanded ? 90 : 0,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isRefreshExpanded.toggle()
                                        }
                                    }
                                )
                                if !isRefreshExpanded {
                                    Text(localizer.text(.photoWallCustomRefreshHint))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 2)
                                }
                                if isRefreshExpanded {
                                    photoWallOptionRow(
                                        title: localizer.text(.photoWallOptionDaily),
                                        subtitle: nil,
                                        inlineTag: localizer.text(.photoWallCurrentLabel),
                                        action: { activePhotoWallOption = .daily }
                                    )
                                    photoWallOptionRow(
                                        title: localizer.text(.photoWallOptionRandomOnce),
                                        subtitle: photoWallRandomOnceSubtitle,
                                        action: { activePhotoWallOption = .randomOnce }
                                    )
                                    photoWallOptionRow(
                                        title: localizer.text(.photoWallOptionManual),
                                        subtitle: photoWallManualSubtitle,
                                        action: { activePhotoWallOption = .manual }
                                    )
                                }
                            }
                            .id(photoWallSectionID)

                        }
                        .scrollContentBackground(.hidden)
                        .onChange(of: scrollToPhotoWall) { newValue in
                            if newValue {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(photoWallSectionID, anchor: .top)
                                }
                                onScrollToPhotoWallHandled?()
                            }
                        }
                        .onAppear {
                            if scrollToPhotoWall {
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(photoWallSectionID, anchor: .top)
                                    }
                                    onScrollToPhotoWallHandled?()
                                }
                            }
                        }
                    }
                }

                if let option = activePhotoWallOption {
                    photoWallModal(for: option)
                }
            }
            .background(theme.rootBackground)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.text(.actionDone)) {
                        onClose?()
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingMonthFilter) {
                MonthFilterView(
                    photoFilter: $userSettings.photoTimeFilter,
                    videoFilter: $userSettings.videoTimeFilter,
                    availableMonths: availableMonths,
                    isLoading: isMonthListLoading
                )
                .environment(\.appTheme, theme)
                .environment(\.localizer, localizer)
            }
            .onChange(of: activePhotoWallOption) { newValue in
                if newValue == .manual {
                    manualSelectionError = nil
                }
                if newValue == .customBackground {
                    backgroundSelectionError = nil
                }
            }
            .sheet(isPresented: $isShowingManualPicker) {
                PhotoWallAssetPicker(selectionLimit: widgetManualSelectionLimit) { identifiers in
                    handleManualPickerSelection(identifiers)
                }
            }
            .sheet(isPresented: $isShowingBackgroundPicker) {
                PhotoWallBackgroundPicker { image in
                    handleCustomBackgroundImage(image)
                }
            }
            .fullScreenCover(isPresented: $isShowingBackgroundCropper) {
                if let image = pendingBackgroundImage {
                    PhotoWallBackgroundCropper(
                        image: image,
                        onCancel: {
                            pendingBackgroundImage = nil
                            isShowingBackgroundCropper = false
                        },
                        onConfirm: { square, wide in
                            handleCustomBackgroundImages(square: square, wide: wide)
                            pendingBackgroundImage = nil
                            isShowingBackgroundCropper = false
                        }
                    )
                } else {
                    Color.clear
                        .onAppear {
                            isShowingBackgroundCropper = false
                        }
                }
            }
            .alert(isPresented: Binding(
                get: { backgroundSelectionError != nil },
                set: { newValue in
                    if !newValue { backgroundSelectionError = nil }
                }
            )) {
                Alert(
                    title: Text(localizer.text(.photoWallBackgroundModalTitle)),
                    message: Text(backgroundSelectionError ?? ""),
                    dismissButton: .default(Text(localizer.text(.actionDone)))
                )
            }
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 10) {
            Image(theme.brandLogoAssetName)
                .resizable()
                .scaledToFit()
                .frame(height: titleIconSize)
                .accessibilityHidden(true)
            Text(localizer.text(.settingsNavigationTitle))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var languageOverrideBinding: Binding<AppLanguage?> {
        Binding(
            get: { settings.languageOverride },
            set: { settings.languageOverride = $0 }
        )
    }

    private var timeFilterSummary: String {
        switch userSettings.photoTimeFilter {
        case .all:
            return localizer.text(.timeFilterAllTime)
        case let .months(months):
            guard !months.isEmpty else { return localizer.text(.timeFilterAllTime) }
            let sorted = months.sorted { lhs, rhs in
                if lhs.year == rhs.year { return lhs.month > rhs.month }
                return lhs.year > rhs.year
            }
            let labels = sorted.prefix(3).map { month in
                switch localizer.language {
                case .english:
                    return "\(month.month)/\(month.year)"
                case .simplifiedChinese:
                    return "\(month.year)年\(month.month)月"
                }
            }
            let separator = localizer.language == .english ? ", " : "、"
            if months.count > 3 {
                let suffix = localizer.language == .english ? " etc." : " 等"
                return labels.joined(separator: separator) + suffix
            }
            return labels.joined(separator: separator)
        }
    }

    private var photoWallRandomOnceSubtitle: String? {
        photoWallSettings.pendingOneTimeRandom ? localizer.text(.photoWallRandomOncePending) : nil
    }

    private var photoWallManualSubtitle: String? {
        if photoWallSettings.mode == .manual {
            return manualCountText(photoWallSettings.manualAssetIdentifiers.count)
        }
        return nil
    }

    private var photoWallBackgroundSubtitle: String? {
        if hasCustomBackground {
            return localizer.text(.photoWallBackgroundCustomLabel)
        }
        return backgroundStyleLabel(photoWallSettings.backgroundStyle)
    }

    private var hasCustomBackground: Bool {
        photoWallSettings.customBackgroundFileNameSquare != nil
            || photoWallSettings.customBackgroundFileNameWide != nil
            || photoWallSettings.customBackgroundFileName != nil
    }

    @ViewBuilder
    private func photoWallOptionRow(
        title: String,
        subtitle: String?,
        inlineTag: String? = nil,
        trailingValue: String? = nil,
        trailingIconRotation: Double = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.body.weight(.medium))
                        if let inlineTag {
                            Text(inlineTag)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let trailingValue {
                    Text(trailingValue)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(trailingIconRotation))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func photoWallModal(for option: PhotoWallOption) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { activePhotoWallOption = nil }

            VStack(spacing: 16) {
                Text(modalTitle(for: option))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(modalMessage(for: option))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if option == .customBackground {
                    VStack(spacing: 10) {
                        ForEach(PhotoWallBackgroundStyle.allCases, id: \.self) { style in
                            Button {
                                handleBackgroundPresetSelection(style)
                            } label: {
                                HStack {
                                    Text(backgroundStyleLabel(style))
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    if !hasCustomBackground && photoWallSettings.backgroundStyle == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: "#6F86C9"))
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        isShowingBackgroundPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                            Text(localizer.text(.photoWallBackgroundPickPhoto))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if option == .manual {
                    if let manualSelectionError {
                        Text(manualSelectionError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        isShowingManualPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(localizer.text(.photoWallManualSelectButton))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    Button(localizer.text(.actionCancel)) {
                        activePhotoWallOption = nil
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if option != .manual && option != .customBackground {
                        Button(localizer.text(.actionConfirm)) {
                            handlePhotoWallModalConfirm(option)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }

    private func modalTitle(for option: PhotoWallOption) -> String {
        switch option {
        case .daily:
            return localizer.text(.photoWallDailyModalTitle)
        case .randomOnce:
            return localizer.text(.photoWallRandomOnceModalTitle)
        case .manual:
            return localizer.text(.photoWallManualModalTitle)
        case .customBackground:
            return localizer.text(.photoWallBackgroundModalTitle)
        }
    }

    private func modalMessage(for option: PhotoWallOption) -> String {
        switch option {
        case .daily:
            return localizer.text(.photoWallDailyModalMessage)
        case .randomOnce:
            return localizer.text(.photoWallRandomOnceModalMessage)
        case .manual:
            return localizer.text(.photoWallManualModalMessage)
        case .customBackground:
            return localizer.text(.photoWallBackgroundModalMessage)
        }
    }

    private func handlePhotoWallModalConfirm(_ option: PhotoWallOption) {
        switch option {
        case .daily:
            photoWallSettings.mode = .daily
            photoWallSettings.manualAssetIdentifiers.removeAll()
            photoWallSettings.pendingOneTimeRandom = false
            onSelectPhotoWallDaily?()
        case .randomOnce:
            photoWallSettings.mode = .daily
            photoWallSettings.manualAssetIdentifiers.removeAll()
            photoWallSettings.pendingOneTimeRandom = true
            onSelectPhotoWallRandomOnce?()
        case .manual:
            break
        case .customBackground:
            break
        }
        activePhotoWallOption = nil
    }

    private func handleManualPickerSelection(_ identifiers: [String]) {
        guard activePhotoWallOption == .manual else { return }
        isShowingManualPicker = false
        if identifiers.isEmpty {
            return
        }

        if identifiers.count < widgetManualSelectionMin {
            manualSelectionError = localizer.text(.photoWallManualInvalidCount)
            return
        }

        manualSelectionError = nil
        photoWallSettings.mode = .manual
        photoWallSettings.manualAssetIdentifiers = identifiers
        photoWallSettings.pendingOneTimeRandom = false
        onSelectPhotoWallManual?(identifiers)
        activePhotoWallOption = nil
    }

    private func handleBackgroundPresetSelection(_ style: PhotoWallBackgroundStyle) {
        var updated = photoWallSettings
        updated.backgroundStyle = style
        updated.customBackgroundFileNameSquare = nil
        updated.customBackgroundFileNameWide = nil
        updated.customBackgroundFileName = nil
        photoWallSettings = updated
        WidgetPhotoStore.clearPhotoWallBackgroundData()
        activePhotoWallOption = nil
        WidgetCenter.shared.reloadTimelines(ofKind: PhotoWallWidgetKind.name)
    }

    private func handleCustomBackgroundImage(_ image: UIImage?) {
        isShowingBackgroundPicker = false
        guard let image else {
            pendingBackgroundImage = nil
            return
        }
        pendingBackgroundImage = image
        isShowingBackgroundCropper = true
        activePhotoWallOption = nil
    }

    private func handleCustomBackgroundImages(square: UIImage, wide: UIImage) {
        guard
            let squareFileName = WidgetPhotoStore.savePhotoWallBackgroundImage(square, storeToDefaults: false),
            let wideFileName = WidgetPhotoStore.savePhotoWallBackgroundImage(wide, storeToDefaults: false)
        else {
            backgroundSelectionError = localizer.text(.photoWallBackgroundSaveFailed)
            return
        }
        var updated = photoWallSettings
        updated.customBackgroundFileNameSquare = squareFileName
        updated.customBackgroundFileNameWide = wideFileName
        updated.customBackgroundFileName = nil
        photoWallSettings = updated
        WidgetPhotoStore.clearPhotoWallBackgroundData()
        backgroundSelectionError = nil
        WidgetCenter.shared.reloadTimelines(ofKind: PhotoWallWidgetKind.name)
    }

    private func backgroundStyleLabel(_ style: PhotoWallBackgroundStyle) -> String {
        switch style {
        case .blackVelvet:
            return localizer.text(.photoWallBackgroundBlackVelvet)
        case .whitePaper:
            return localizer.text(.photoWallBackgroundGrayPaper)
        case .warmPaper:
            return localizer.text(.photoWallBackgroundWarmPaper)
        case .newspaper:
            return localizer.text(.photoWallBackgroundWood)
        }
    }

    private func manualCountText(_ count: Int) -> String {
        switch localizer.language {
        case .english:
            return "Selected \(count)"
        case .simplifiedChinese:
            return "已选择 \(count) 张"
        }
    }
}

private extension CompactSettingsView {
    enum PhotoWallOption: Identifiable, Equatable {
        case customBackground
        case daily
        case randomOnce
        case manual

        var id: Int {
            switch self {
            case .customBackground: return 0
            case .daily: return 1
            case .randomOnce: return 2
            case .manual: return 3
            }
        }
    }

    var widgetManualSelectionMin: Int { 6 }
    var widgetManualSelectionLimit: Int { 16 }
}

private struct PhotoWallAssetPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([String]) -> Void

        init(onComplete: @escaping ([String]) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            let identifiers = results.compactMap { $0.assetIdentifier }
            onComplete(identifiers)
        }
    }
}

private struct PhotoWallBackgroundPicker: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true) {
                    self.onComplete(nil)
                }
                return
            }
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true) {
                    self.onComplete(nil)
                }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async {
                    picker.dismiss(animated: true) {
                        self.onComplete(image)
                    }
                }
            }
        }
    }
}

#Preview {
    CompactSettingsView(
        settings: .constant(DeveloperSettings()),
        userSettings: .constant(UserSettings()),
        photoWallSettings: .constant(PhotoWallSettings()),
        availableMonths: [
            YearMonth(year: 2024, month: 10): 12,
            YearMonth(year: 2023, month: 6): 4
        ],
        isMonthListLoading: false,
        onClose: {}
    )
        .environment(\.appTheme, .dark)
        .environment(\.localizer, AppLocalizer(language: .simplifiedChinese))
}
