//
//  FavoriteComposerView.swift
//  memoflick
//
//  Created by Codex on 2025/12/10.
//

import SwiftUI

struct FavoriteComposerRequest: Identifiable {
    let id = UUID()
    let title: String
    let initialCaption: String?
    let initialCategory: String?
    let onSubmit: (FavoriteMetadata) -> Void
}

struct FavoriteComposerView: View {
    let request: FavoriteComposerRequest
    @ObservedObject var categoryStore: FavoriteCategoryStore
    let onCancel: () -> Void
    let onComplete: (FavoriteMetadata) -> Void

    @State private var captionText: String
    @State private var selectedCategory: String
    @State private var newCategoryName: String = ""
    @State private var isAddingNew: Bool = false
    @Environment(\.localizer) private var localizer
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.colorScheme) private var colorScheme

    private let iosBlue = Color(hex: "#007AFF")
    private let lightBg = Color(hex: "#F2F2F7")
    private let darkBg = Color(hex: "#1C1C1E")
    private let darkSurface = Color(hex: "#2C2C2E")
    private let dividerColor = Color.white.opacity(0.08)

    init(
        request: FavoriteComposerRequest,
        categoryStore: FavoriteCategoryStore,
        onCancel: @escaping () -> Void,
        onComplete: @escaping (FavoriteMetadata) -> Void
    ) {
        self.request = request
        self.categoryStore = categoryStore
        self.onCancel = onCancel
        self.onComplete = onComplete

        _captionText = State(initialValue: request.initialCaption ?? "")
        let normalizedCategory = categoryStore.normalizeCategoryName(request.initialCategory)
        _selectedCategory = State(initialValue: normalizedCategory)
        categoryStore.ensureCategoryExists(normalizedCategory)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            GeometryReader { proxy in
                let cardWidth = min(proxy.size.width * 0.9, 340)

                VStack(spacing: 0) {
                    header
                    categorySection
                        .padding(.bottom, 6)

                    notesSection
                        .padding(.top, 6)

                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .padding(.top, 8)
                }
                .frame(width: cardWidth)
                .background(backgroundColor)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 40, x: 0, y: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, max(0, (proxy.size.width - cardWidth) / 2))
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedCategory)
        .animation(.easeInOut(duration: 0.2), value: isAddingNew)
    }
}

private extension FavoriteComposerView {
    var header: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 42, height: 5)
                .padding(.top, 12)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.text(.favoriteComposerPrimaryTitle))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    if !request.title.isEmpty {
                        Text(request.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { onCancel() }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.gray.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 2)
        }
        .padding(.bottom, 6)
    }

    var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizer.text(.favoriteComposerPickerTitle))
                    .font(.system(size: 14, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.gray)

                Spacer()

                if !isAddingNew {
                    Button(action: { withAnimation { isAddingNew = true } }) {
                        Label(localizer.text(.favoriteComposerNewButton), systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(iosBlue)
                    }
                }
            }
            .padding(.horizontal, 22)

            if isAddingNew {
                HStack(spacing: 10) {
                    TextField(localizer.text(.favoriteComposerNamePlaceholder), text: $newCategoryName)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(secondaryBgColor)
                        .cornerRadius(12)
                        .onSubmit(confirmNewCategory)

                    Button(action: { confirmNewCategory() }) {
                        Text(localizer.text(.favoriteComposerConfirmNewButton))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(iosBlue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 22)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category
                            }
                        }) {
                            Text(FavoriteCategoryStore.displayName(for: category, language: appLanguage))
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedCategory == category ? iosBlue : secondaryBgColor)
                                .foregroundColor(selectedCategory == category ? .white : secondaryTextColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: selectedCategory == category ? iosBlue.opacity(0.35) : .clear, radius: 5, x: 0, y: 3)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 6)
    }

    var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.text(.favoriteComposerCaptionTitle))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)

            TextField(localizer.text(.favoriteComposerCaptionPlaceholder), text: $captionText)
                .padding(12)
                .background(secondaryBgColor.opacity(0.8))
                .cornerRadius(14)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { onCancel() }) {
                Text(localizer.text(.actionCancel))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(secondaryBgColor)
                    .foregroundColor(secondaryTextColor)
                    .cornerRadius(12)
            }

            Button(action: { submit() }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text(localizer.text(.favoriteComposerSaveButton))
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(iosBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: iosBlue.opacity(0.35), radius: 10, x: 0, y: 6)
            }
            .disabled(selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    var categories: [String] {
        categoryStore.availableCategories
    }

    var backgroundColor: Color {
        colorScheme == .dark ? darkBg : Color.white
    }

    var secondaryBgColor: Color {
        colorScheme == .dark ? darkSurface : lightBg
    }

    var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.gray : Color.black.opacity(0.7)
    }

    func confirmNewCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = categoryStore.normalizeCategoryName(trimmed)
        categoryStore.addCategoryIfNeeded(normalized)
        selectedCategory = normalized
        newCategoryName = ""
        withAnimation {
            isAddingNew = false
        }
    }

    func submit() {
        let metadata = FavoriteMetadata(
            caption: captionText,
            categoryName: selectedCategory
        ).sanitized()
        categoryStore.recordSelection(of: metadata.categoryName)
        onComplete(metadata)
    }
}
