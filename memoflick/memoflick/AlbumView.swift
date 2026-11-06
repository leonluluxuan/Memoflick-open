//
//  AlbumView.swift
//  memoflick
//
//  Created by Codex on 2025/11/03.
//

import SwiftUI
import Photos
import AVKit
import UIKit
import Foundation
import Combine

private struct StrictCalendarManager {
    static let shared = StrictCalendarManager()
    let calendar: Calendar

    private init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.locale = .current
        cal.firstWeekday = 2 // 周一为首日，如需周日改为 1
        calendar = cal
    }
}

struct AlbumView: View {
    enum Tab: CaseIterable {
        case kept
        case collections
        case trash

        func title(using localizer: AppLocalizer) -> String {
            switch self {
            case .kept:
                return localizer.text(.albumTabKept)
            case .collections:
                return localizer.text(.albumTabCollections)
            case .trash:
                return localizer.text(.albumTabTrash)
            }
        }
    }

    let keptItems: [AlbumMediaItem]
    let favoriteItems: [AlbumMediaItem]
    let trashItems: [AlbumMediaItem]
    @Binding var selectedTab: Tab
    @Binding var isPreviewing: Bool
    let onRestore: ([AlbumMediaItem]) -> Void
    let onDeleteForever: ([AlbumMediaItem]) -> Void
    let onMoveKeptToTrash: ([AlbumMediaItem]) -> Void
    let onFavorite: (AlbumMediaItem) -> Void
    let onReturnHome: () -> Void
    @ObservedObject var categoryStore: FavoriteCategoryStore

    @State private var selectionMode = false
    @State private var selection = Set<String>()
    @State private var previewItemID: String?
    @State private var previewItems: [AlbumMediaItem] = []
    @State private var showDeleteConfirmation = false
    @State private var activeCollectionID: String?
    @State private var injectedKeptItems: [AlbumMediaItem] = []
    @State private var selectedDate: Date?
    @State private var currentMonth = YearMonth(year: 2025, month: 12)
    @State private var dayThumbnailCache: [String: UIImage] = [:]
    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer
    @Environment(\.appLanguage) private var appLanguage
    @Environment(\.simulatedToday) private var simulatedToday
    @StateObject private var trashHistory = TrashHistoryStore.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let earliestMonth = YearMonth(year: 2025, month: 12)
    private let dayImageManager = PHCachingImageManager()
    private let dayImageOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()

    var body: some View {
        ZStack {
            theme.contentBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    switch selectedTab {
                    case .collections:
                        collectionsView
                    case .kept, .trash:
                        if let date = selectedDate {
                            detailView(for: date)
                        } else {
                            overviewView
                                .id(selectedTab) // refresh content on tab switch
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .blur(radius: previewItemID != nil ? 18 : 0)

            if selectionToolbarVisible {
                VStack(spacing: 0) {
                    Spacer()
                    selectionToolbar
                }
                    .transition(.move(edge: .bottom))
            }

            if previewItemID != nil {
                AlbumPreviewView(
                    items: previewItems,
                    selectedItemID: $previewItemID,
                    currentTab: selectedTab,
                    onClose: {
                        previewItemID = nil
                        isPreviewing = false
                    },
                    onFavorite: { item in
                        previewItemID = nil
                        isPreviewing = false
                        onFavorite(item)
                    },
                    onMoveToTrash: handlePreviewMoveToTrash,
                    onInsertNewItem: handleInsertNewItem
                )
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .confirmationDialog(
            localizer.text(.albumDeleteConfirmationTitle),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(localizer.text(.actionDelete), role: .destructive) {
                performDeleteSelection()
            }
            Button(localizer.text(.actionCancel), role: .cancel) { }
        }
        .onChange(of: selectedTab) { _ in
            exitSelectionMode()
            activeCollectionID = nil
            selectedDate = nil
            updateCurrentMonthToLatest()
            prefetchMonthThumbnails()
            previewItemID = nil
            previewItems = []
            isPreviewing = false
        }
        .onChange(of: selectedDate) { newValue in
            if newValue == nil {
                exitSelectionMode()
            }
        }
        .onAppear {
            updateCurrentMonthToLatest()
            prefetchMonthThumbnails()
        }
        .onChange(of: baseItems.map(\.id)) { _ in
            prefetchMonthThumbnails()
        }
        .onChange(of: trashHistory.records.keys.sorted()) { _ in
            prefetchMonthThumbnails()
        }
        .onChange(of: currentMonth) { _ in
            prefetchMonthThumbnails()
        }
        .animation(.easeInOut(duration: 0.18), value: selectionMode)
    }
}

private extension AlbumView {
    var header: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.title(using: localizer)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    var overviewView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                AlbumTodaySection(
                    items: todaySectionItems,
                    selectedTab: selectedTab,
                    sizeText: todaySizeText,
                    countOverride: todayCountOverride,
                    onTap: { openDetail(for: currentDay) }
                )
                .id(selectedTab)
                .padding(.horizontal, 2)

                if shouldShowTrashPendingNotice {
                    trashPendingNoticeBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                AlbumAllSection(
                    currentMonth: $currentMonth,
                    minMonth: earliestMonth,
                    calendar: calendar,
                    daySummaries: daySummaries,
                    thumbnailProvider: { dayThumbnail(for: $0) },
                    onNeedThumbnail: { loadDayThumbnailIfNeeded(for: $0) },
                    onSelectDay: { date in
                        openDetail(for: date)
                    }
                )
                .padding(.horizontal, 16)

            }
            .padding(.top, 14)
            .padding(.bottom, selectionToolbarVisible ? 60 : 34)
        }
    }

    private var shouldShowTrashPendingNotice: Bool {
        selectedTab == .trash
            && trashItems.contains { calendar.isDate($0.actionDate, inSameDayAs: currentDay) }
    }

    private var trashPendingNoticeBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.red)

            Text(localizer.text(.albumTrashPendingNotice))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.dividerColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            openDetail(for: currentDay)
        }
    }

    func detailView(for date: Date) -> some View {
        VStack(spacing: 0) {
            detailHeader(for: date)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(currentItems) { item in
                        let isSelected = selection.contains(item.id)
                        AlbumGridTile(
                            item: item,
                            isSelected: isSelected,
                            selectionMode: selectionMode
                        )
                        .onTapGesture {
                            handleTap(on: item)
                        }
                        .contextMenu {
                            if selectedTab == .trash && !selectionMode {
                                Button(localizer.text(.actionRestore), systemImage: "arrow.uturn.backward") {
                                    onRestore([item])
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, selectionToolbarVisible ? 100 : 24)
            }
            .overlay(gridPlaceholderView.opacity(currentItems.isEmpty ? 1 : 0))
        }
    }

    var collectionsView: some View {
        AlbumCollectionsView(
            onReturnHome: onReturnHome,
            categoryStore: categoryStore,
            isPreviewing: $isPreviewing
        )
    }

    var baseItems: [AlbumMediaItem] {
        switch selectedTab {
        case .kept:
            return injectedKeptItems + keptItems
        case .collections:
            return []
        case .trash:
            return trashItems
        }
    }

    var currentItems: [AlbumMediaItem] {
        guard let selectedDate else { return baseItems }
        let dayStart = StrictCalendarManager.shared.calendar.startOfDay(for: selectedDate)
        return baseItems.filter { item in
            StrictCalendarManager.shared.calendar.isDate(item.actionDate, inSameDayAs: dayStart)
        }
    }

    var selectionToolbarVisible: Bool {
        selectionMode && selectedTab != .collections && selectedDate != nil
    }

    var gridPlaceholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.fill.on.rectangle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.gray)
            Text(gridPlaceholderText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    var gridPlaceholderText: String {
        if selectedTab == .kept {
            return localizer.text(.albumGridEmptyKept)
        } else {
            if let date = selectedDate,
               let record = trashHistory.record(for: date),
               record.totalCount >= 0 {
                let sizeText = record.totalBytes > 0 ? AlbumMediaItem.formatBytes(record.totalBytes) : ""
                if sizeText.isEmpty {
                    return String(format: localizer.text(.albumTodayCountFormat), record.totalCount)
                } else {
                    return String(format: localizer.text(.albumTodayCountWithSizeFormat), record.totalCount, sizeText)
                }
            }
            return localizer.text(.albumGridEmptyTrash)
        }
    }

    var selectedItems: [AlbumMediaItem] {
        let ids = selection
        return currentItems.filter { ids.contains($0.id) }
    }

    var favoriteCategories: [AlbumCollectionCategory] {
        let groups = Dictionary(grouping: favoriteItems) { categoryDisplayName(for: $0) }
        return groups
            .map { title, items in
                AlbumCollectionCategory(id: title, title: title, items: items)
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }

    func categoryDisplayName(for item: AlbumMediaItem) -> String {
        FavoriteCategoryStore.displayName(for: item.categoryName, language: appLanguage)
    }

    var defaultCollectionName: String {
        FavoriteCategoryStore.localizedDefaultName(for: appLanguage)
    }

    var isAllSelected: Bool {
        !currentItems.isEmpty && selection.count == currentItems.count
    }

    private var calendar: Calendar { StrictCalendarManager.shared.calendar }
    private var earliestDayStart: Date { utcMidday(for: earliestMonth) }
    private var currentDay: Date { simulatedToday ?? Date() }

    var selectionToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(localizer.albumSelectionStatus(count: selection.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isAllSelected ? localizer.text(.actionUnselectAll) : localizer.text(.actionSelectAll)) {
                    toggleSelectAll()
                }
                .disabled(currentItems.isEmpty)

                if selectedTab == .kept {
                    Button(localizer.text(.actionMoveToTrash)) {
                        handleMoveKeptToTrash()
                    }
                    .disabled(selection.isEmpty)
                } else {
                    Button(localizer.text(.actionRestore)) {
                        handleRestoreSelection()
                    }
                    .disabled(selection.isEmpty)

                    Button(localizer.text(.actionDelete), role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: -10)
    }

    func handleTap(on item: AlbumMediaItem) {
        if selectionMode {
            toggleSelection(for: item)
        } else {
            previewItems = currentItems
            previewItemID = item.id
            isPreviewing = true
        }
    }

    func toggleSelectionMode() {
        guard selectedTab != .collections else { return }
        if selectionMode {
            exitSelectionMode()
        } else {
            selectionMode = true
        }
    }

    func exitSelectionMode() {
        selectionMode = false
        selection.removeAll()
        showDeleteConfirmation = false
    }

    func toggleSelection(for item: AlbumMediaItem) {
        if selection.contains(item.id) {
            selection.remove(item.id)
        } else {
            selection.insert(item.id)
        }
    }

    func toggleSelectAll() {
        if isAllSelected {
            selection.removeAll()
        } else {
            selection = Set(currentItems.map(\.id))
        }
    }

    func handleRestoreSelection() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        onRestore(items)
        selection.removeAll()
    }

    func handleMoveKeptToTrash() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        onMoveKeptToTrash(items)
        selection.removeAll()
    }

    func handleInsertNewItem(_ item: AlbumMediaItem) {
        // 仅在已保留视图中注入新压缩副本
        injectedKeptItems.insert(item, at: 0)
        previewItems = currentItems
        previewItemID = item.id
    }

    func handlePreviewMoveToTrash(_ item: AlbumMediaItem) {
        guard selectedTab != .trash else { return }
        onMoveKeptToTrash([item])
        previewItemID = nil
        isPreviewing = false
    }

    func performDeleteSelection() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        onDeleteForever(items)
        selection.removeAll()
        showDeleteConfirmation = false
    }

    func openDetail(for date: Date) {
        let day = calendar.startOfDay(for: date)
        guard day >= earliestDayStart else {
            currentMonth = earliestMonth
            return
        }
        selectedDate = day
        currentMonth = max(YearMonth(date: day) ?? earliestMonth, earliestMonth)
        selectionMode = false
        selection.removeAll()
    }

    func detailHeader(for date: Date) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selectedDate = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text(formattedDate(for: date))
                }
                .font(.system(size: 17, weight: .semibold))
            }

            Spacer()

            Button(selectionMode ? localizer.text(.actionDone) : localizer.text(.actionSelect)) {
                toggleSelectionMode()
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .disabled(currentItems.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    var todaySectionItems: [AlbumMediaItem] {
        let todayItems = baseItems
            .filter { calendar.isDate($0.actionDate, inSameDayAs: currentDay) }
            .sorted { $0.actionDate < $1.actionDate } // earliest first

        if selectedTab == .trash {
            if !todayItems.isEmpty {
                return Array(todayItems.prefix(3))
            }
            if let record = trashHistory.record(for: currentDay), let thumbnailData = record.thumbnailData, let image = UIImage(data: thumbnailData) {
                let synthetic = AlbumMediaItem(testImage: image, date: currentDay, id: "trash-log-\(record.dateKey)", status: .trashed, compressedSizeBytes: record.totalBytes)
                return [synthetic]
            }
        }

        return Array(todayItems.prefix(3))
    }

    var todaySizeText: String? {
        guard selectedTab == .trash, let record = trashHistory.record(for: currentDay) else { return nil }
        let bytes = record.totalBytes
        guard bytes > 0 else { return nil }
        return AlbumMediaItem.formatBytes(bytes)
    }

    var todayCountOverride: Int? {
        guard selectedTab == .trash, let record = trashHistory.record(for: currentDay) else { return nil }
        return record.totalCount
    }

    var daySections: [AlbumDaySection] {
        let grouped = Dictionary(grouping: baseItems) { item in
            calendar.startOfDay(for: item.actionDate)
        }
        var sections = grouped
            .filter { $0.key >= earliestDayStart }
            .map { date, items in
                AlbumDaySection(date: date, items: items.sorted { $0.actionDate > $1.actionDate }) }
        if selectedTab == .trash {
            for record in trashHistory.allRecords {
                let day = calendar.startOfDay(for: record.date)
                guard day >= earliestDayStart else { continue }
                if sections.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                    continue
                }
                if let data = record.thumbnailData, let image = UIImage(data: data) {
                    let item = AlbumMediaItem(testImage: image, date: record.date, id: "trash-log-\(record.dateKey)", status: .trashed, compressedSizeBytes: record.totalBytes)
                    sections.append(AlbumDaySection(date: day, items: [item]))
                }
            }
        }
        return sections.sorted { $0.date > $1.date }
    }

    var daySummaries: [Date: AlbumDaySummary] {
        let grouped = Dictionary(grouping: baseItems) { item in
            calendar.startOfDay(for: item.actionDate)
        }
        var result = grouped
            .filter { $0.key >= earliestDayStart }
            .reduce(into: [Date: AlbumDaySummary]()) { partialResult, element in
                let date = element.key
                let items = element.value.sorted { $0.actionDate < $1.actionDate } // earliest first
                partialResult[date] = AlbumDaySummary(date: date, count: items.count, leadItem: items.first)
            }
        if selectedTab == .trash {
            for record in trashHistory.allRecords {
                let day = calendar.startOfDay(for: record.date)
                guard day >= earliestDayStart else { continue }
                if result[day] == nil {
                    let lead: AlbumMediaItem?
                    if let data = record.thumbnailData, let image = UIImage(data: data) {
                        lead = AlbumMediaItem(testImage: image, date: record.date, id: "trash-log-\(record.dateKey)", status: .trashed, compressedSizeBytes: record.totalBytes)
                    } else {
                        lead = nil
                    }
                    result[day] = AlbumDaySummary(date: day, count: record.totalCount, leadItem: lead)
                }
            }
        }
        return result
    }

    func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLanguage == .simplifiedChinese ? Locale(identifier: "zh_Hans_CN") : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = appLanguage == .simplifiedChinese ? "yyyy年M月d日" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    func dayCacheKey(for day: Date) -> String {
        let dayStart = calendar.startOfDay(for: day)
        let stamp = Int(dayStart.timeIntervalSince1970)
        return "\(selectedTab)-\(stamp)"
    }

    func dayThumbnail(for day: Date) -> UIImage? {
        dayThumbnailCache[dayCacheKey(for: day)]
    }

    func loadDayThumbnailIfNeeded(for summary: AlbumDaySummary) {
        let key = dayCacheKey(for: summary.date)
        if dayThumbnailCache[key] != nil { return }

        if let testImage = summary.leadItem?.testImage?.image {
            dayThumbnailCache[key] = testImage
            return
        }

        guard let asset = summary.leadItem?.asset else { return }
        let targetSize = CGSize(width: 200, height: 200)
        dayImageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: dayImageOptions
        ) { image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                dayThumbnailCache[key] = image
            }
        }
    }

    func updateCurrentMonthToLatest() {
        let latestDate = baseItems
            .map { $0.actionDate }
            .filter { $0 >= earliestDayStart }
            .max() ?? earliestDayStart
        currentMonth = max(YearMonth(date: latestDate) ?? earliestMonth, earliestMonth)
    }

    func prefetchMonthThumbnails() {
        let summaries = daySummaries.values
        for summary in summaries {
            guard summary.count > 0 else { continue }
            guard let ym = yearMonth(for: summary.date), ym == currentMonth else { continue }
            loadDayThumbnailIfNeeded(for: summary)
        }
    }

    func yearMonth(for date: Date) -> YearMonth? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return YearMonth(year: year, month: month)
    }

    private var latestMonth: YearMonth {
        YearMonth(date: currentDay) ?? earliestMonth
    }

    private func utcMidday(for ym: YearMonth, day: Int = 1) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return utc.date(from: DateComponents(timeZone: utc.timeZone, year: ym.year, month: ym.month, day: day, hour: 12)) ?? Date()
    }
}

private extension YearMonth {
    func addingMonths(_ delta: Int) -> YearMonth {
        var y = year
        var m = month + delta
        while m > 12 { m -= 12; y += 1 }
        while m < 1 { m += 12; y -= 1 }
        return YearMonth(year: y, month: m)
    }
}

private struct AlbumDaySection: Identifiable {
    let id: Date
    let date: Date
    let items: [AlbumMediaItem]

    init(date: Date, items: [AlbumMediaItem]) {
        self.id = date
        self.date = date
        self.items = items
    }
}

private struct AlbumDaySummary {
    let date: Date
    let count: Int
    let leadItem: AlbumMediaItem?
}

    private struct AlbumTodaySection: View {
        let items: [AlbumMediaItem]
        let selectedTab: AlbumView.Tab
        var sizeText: String? = nil
        var countOverride: Int? = nil
    let onTap: () -> Void

        @Environment(\.localizer) private var localizer

        private var titleText: String {
            if selectedTab == .trash {
                return localizer.text(.albumTodayTitleTrash)
            } else {
                return localizer.text(.albumTodayTitleKept)
            }
        }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleText)
                .font(.title3.weight(.bold))
                .padding(.horizontal, 16)
                .padding(.top, 6)

            if selectedTab == .trash, items.isEmpty, (countOverride ?? 0) > 0, let sizeText {
                VStack(spacing: 6) {
                    Text(localizer.text(.albumTodaySummaryLabelTrash))
                        .font(.headline.weight(.semibold))
                    Text(String(format: localizer.text(.albumTodayCountFormat), countOverride ?? 0))
                        .font(.headline.weight(.semibold))
                    Text(sizeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
            let availableWidth = UIScreen.main.bounds.width - 32
            let itemSpacing: CGFloat = 12
            let side = max(70, floor((availableWidth - itemSpacing * 3) / 4))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    if selectedTab == .trash, items.isEmpty, let sizeText, let countOverride, countOverride > 0 {
                        summaryEmptyCard(count: countOverride, sizeText: sizeText, side: side)
                            .frame(width: side, height: side)
                    } else {
                        ForEach(Array(items.prefix(3)), id: \.id) { item in
                            AlbumInlineImage(item: item, cornerRadius: 12, side: side)
                                .frame(width: side, height: side)
                                .onTapGesture(perform: onTap)
                        }

                        summaryCard(side: side)
                            .frame(width: side, height: side)
                            .onTapGesture(perform: onTap)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        }
    }

    private func summaryCard(side: CGFloat) -> some View {
        ZStack {
            if let item = items.first {
                AlbumInlineImage(item: item, cornerRadius: 12, side: side) {
                    Color.black.opacity(0.55)
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
            }

            VStack(spacing: 4) {
                Text(selectedTab == .trash ? localizer.text(.albumTodaySummaryLabelTrash) : localizer.text(.albumTodaySummaryLabelKept))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(String(format: localizer.text(.albumTodayCountFormat), countOverride ?? items.count))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                if let sizeText, selectedTab == .trash {
                    Text(sizeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    private func summaryEmptyCard(count: Int, sizeText: String, side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
            VStack(spacing: 6) {
                Text(localizer.text(.albumTodaySummaryLabelTrash))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(String(format: localizer.text(.albumTodayCountFormat), count))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Text("(\(sizeText))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AlbumAllSection: View {
    @Binding var currentMonth: YearMonth
    let minMonth: YearMonth
    let calendar: Calendar
    let daySummaries: [Date: AlbumDaySummary]
    let thumbnailProvider: (Date) -> UIImage?
    let onNeedThumbnail: (AlbumDaySummary) -> Void
    let onSelectDay: (Date) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer
    @Environment(\.colorScheme) private var colorScheme

    private var monthLabel: String {
        switch localizer.language {
        case .english:
            return "\(currentMonth.month)/\(currentMonth.year)"
        case .simplifiedChinese:
            return "\(currentMonth.year)年\(currentMonth.month)月"
        }
    }

    private var weekdaySymbols: [String] {
        let base: [String]
        switch localizer.language {
        case .english:
            base = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        case .simplifiedChinese:
            base = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        }
        // 日历已固定以周一为首，因此保持顺序即可。
        return base
    }

    private var canGoPrevious: Bool { currentMonth > minMonth }
    private var canGoNext: Bool { true }

    private var cardBackground: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.06)
        default:
            return theme.elevatedBackground
        }
    }

    private var cardStroke: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.08)
        default:
            return Color.black.opacity(0.04)
        }
    }

    private var cardShadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.black.opacity(0.08)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            calendarGrid
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(localizer.language == .simplifiedChinese ? "全部" : "All")
                .font(.title3.weight(.bold))
            Spacer()
            HStack(spacing: 10) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(theme.elevatedBackground.opacity(0.9))
                        )
                }
                .disabled(!canGoPrevious)
                .opacity(canGoPrevious ? 1 : 0.35)

                Text(monthLabel)
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 4)

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(theme.elevatedBackground.opacity(0.9))
                        )
                }
                .disabled(!canGoNext)
                .opacity(canGoNext ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 0)
    }

    private var calendarGrid: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let spacing: CGFloat = 6
            let cells = monthCells(for: currentMonth)
            let cellSide = (side - spacing * 6) / 7
            let rows = max(1, Int(ceil(Double(cells.count) / 7.0)))
            let weekdayHeight: CGFloat = 18
            let contentHeight = 14 + weekdayHeight + spacing + CGFloat(rows) * cellSide + CGFloat(max(rows - 1, 0)) * spacing + 14

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(cardStroke, lineWidth: 1)
                    )
                    .shadow(color: cardShadowColor, radius: 16, x: 0, y: 12)
                    .frame(height: contentHeight)

                VStack(spacing: 12) {
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7), spacing: spacing) {
                        ForEach(Array(cells.enumerated()), id: \.0) { _, cell in
                            switch cell {
                            case .placeholder:
                                Color.clear.frame(height: cellSide)
                            case let .day(date):
                                dayCell(for: date, cellSide: cellSide)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(height: contentHeight, alignment: .top)
            }
            .frame(width: side, height: contentHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayCell(for date: Date, cellSide: CGFloat) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let dayKey = calendar.startOfDay(for: date)
        let summary = daySummaries[dayKey]
        let hasData = (summary?.count ?? 0) > 0
        let thumbnail = thumbnailProvider(dayKey)
        let imageSide = cellSide

        return Button(action: {
            guard hasData else { return }
            onSelectDay(dayKey)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hasData ? Color.clear : Color.primary.opacity(0.06))

                if hasData, let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSide, height: imageSide)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(hasData ? Color.white : Color.primary.opacity(0.35))
                        .shadow(color: hasData ? .black.opacity(0.35) : .clear, radius: 3, x: 0, y: 1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: cellSide, maxHeight: cellSide)
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            if let summary {
                onNeedThumbnail(summary)
            }
        }
        .onChange(of: summary?.count ?? 0) { newValue in
            guard newValue > 0, let summary else { return }
            onNeedThumbnail(summary)
        }
        .onChange(of: summary?.leadItem?.id) { _ in
            guard let summary, summary.count > 0 else { return }
            onNeedThumbnail(summary)
        }
    }

    private enum MonthCell: Hashable {
        case placeholder
        case day(Date)
    }

    private func monthCells(for month: YearMonth) -> [MonthCell] {
        guard let start = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1)) else { return [] }
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }

        let firstWeekdayIndex = calendar.component(.weekday, from: start)
        let leadingPlaceholders = (firstWeekdayIndex - calendar.firstWeekday + 7) % 7

        var cells: [MonthCell] = Array(repeating: .placeholder, count: leadingPlaceholders)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: start) {
                cells.append(.day(date))
            }
        }
        return cells
    }

    private func changeMonth(by delta: Int) {
        var next = currentMonth.addingMonths(delta)
        if next < minMonth { next = minMonth }
        withAnimation(.easeInOut(duration: 0.18)) {
            currentMonth = next
        }
    }
}

private struct AlbumInlineImage<Overlay: View>: View {
    let item: AlbumMediaItem
    var cornerRadius: CGFloat = 10
    var side: CGFloat?
    var overlay: Overlay

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private let imageManager = PHCachingImageManager()

    init(item: AlbumMediaItem, cornerRadius: CGFloat = 10, side: CGFloat? = nil, @ViewBuilder overlay: () -> Overlay = { EmptyView() }) {
        self.item = item
        self.cornerRadius = cornerRadius
        self.side = side
        self.overlay = overlay()
    }

    var body: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                        .overlay(
                            ProgressView()
                                .tint(.secondary)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            overlay
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: side, height: side)
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .onAppear(perform: load)
        .onDisappear(perform: cancel)
    }

    private func load() {
        guard image == nil else { return }
        if let testImage = item.testImage?.image {
            image = testImage
            return
        }
        guard let asset = item.asset else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 500, height: 500),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                image = result
            }
        }
    }

    private func cancel() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}

private struct CollectionDemoPhoto: Identifiable {
    let id = UUID()
    let color: Color
}

private struct CollectionAlbum: Identifiable {
    let id: String
    var title: String
    var demoPhotos: [CollectionDemoPhoto]
    var systemCollectionID: String?
    var coverAssetID: String?
    var assetCount: Int
    var isDemo: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        demoPhotos: [CollectionDemoPhoto] = [],
        systemCollectionID: String? = nil,
        coverAssetID: String? = nil,
        assetCount: Int = 0,
        isDemo: Bool = false
    ) {
        self.id = id
        self.title = title
        self.demoPhotos = demoPhotos
        self.systemCollectionID = systemCollectionID
        self.coverAssetID = coverAssetID
        self.assetCount = assetCount
        self.isDemo = isDemo
    }

    var photoCount: Int {
        systemCollectionID == nil ? demoPhotos.count : assetCount
    }

    var hasSystemCollection: Bool {
        systemCollectionID != nil
    }
}

private struct AlbumCollectionsView: View {
    let onReturnHome: () -> Void
    @ObservedObject var categoryStore: FavoriteCategoryStore
    @Binding var isPreviewing: Bool
    @State private var albums: [CollectionAlbum] = []
    @State private var searchText = ""
    @State private var selectedAlbum: CollectionAlbum?
    @State private var showNewAlbumModal = false
    @State private var newAlbumName = ""
    @State private var hasInjectedDemoAlbums = false
    @State private var showSyncPrompt = false
    @State private var pendingSyncAlbumID: String?
    @State private var isSyncingSystemAlbums = false
    @State private var hasLoadedSystemAlbums = false
    @State private var pendingDeleteAlbum: CollectionAlbum?
    @State private var showDeleteConfirmation = false
    @State private var duplicateSystemAlbumIDs: [String] = []
    @State private var showCleanupConfirmation = false
    @State private var isCleaningDuplicates = false
    @State private var pendingSystemAlbumTitles: Set<String> = []
    @State private var pendingRenameAlbum: CollectionAlbum?
    @State private var showRenameModal = false
    @State private var renameText = ""
    @State private var renameError: String?
    @State private var coverPickerAlbum: CollectionAlbum?
    @StateObject private var coverStore = CollectionCoverStore()

    @AppStorage("collection_sync_enabled") private var isSystemSyncEnabled = false
    @AppStorage("collection_sync_declined") private var didDeclineSystemSync = false

    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer
    @Environment(\.appLanguage) private var appLanguage

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    // Toggle to remove demo albums entirely.
    private let demoAlbumsEnabled = true

    private var filteredAlbums: [CollectionAlbum] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            if let selectedAlbum {
                CollectionDetailView(
                    album: selectedAlbum,
                    onBack: { withAnimation(.easeInOut(duration: 0.25)) { self.selectedAlbum = nil } },
                    onReturnHome: onReturnHome,
                    isPreviewing: $isPreviewing
                )
                .transition(.move(edge: .trailing))
            } else {
                if albums.isEmpty {
                    CollectionEmptyStateView(
                        onCreate: { openNewAlbumModal() },
                        onSync: { startSystemSync() },
                        isSyncing: isSyncingSystemAlbums
                    )
                } else {
                    collectionListView
                }
            }

            if showNewAlbumModal || showRenameModal || showDeleteConfirmation {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { closeActiveModal() }
                    .transition(.opacity)
            }

            if showNewAlbumModal {
                newAlbumModalView
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(2)
            }

            if showRenameModal {
                renameAlbumModalView
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(2)
            }

            if showDeleteConfirmation {
                deleteAlbumModalView
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedAlbum?.id)
        .sheet(item: $coverPickerAlbum) { album in
            CollectionCoverPickerView(
                album: album,
                initialSelection: coverStore.coverAssetID(for: coverKey(for: album)),
                onCancel: { coverPickerAlbum = nil },
                onSave: { assetID in
                    coverStore.setCover(assetID, for: coverKey(for: album))
                    coverPickerAlbum = nil
                }
            )
        }
        .onAppear(perform: loadSystemAlbumsIfNeeded)
        .onReceive(categoryStore.$categories) { categories in
            syncAlbumsFromCategories(categories)
        }
        .onChange(of: albums.map(\.title)) { _ in
            syncCategoryStoreFromAlbums()
        }
        .confirmationDialog(
            localizer.text(.collectionSyncPromptTitle),
            isPresented: $showSyncPrompt,
            titleVisibility: .visible
        ) {
            Button(localizer.text(.collectionSyncPromptConfirm)) {
                confirmSystemSync()
            }
            Button(localizer.text(.collectionSyncPromptDecline), role: .cancel) {
                declineSystemSync()
            }
        } message: {
            Text(localizer.text(.collectionSyncPromptMessage))
        }
        .confirmationDialog(
            localizer.text(.collectionCleanupTitle),
            isPresented: $showCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button(localizer.text(.collectionCleanupConfirm), role: .destructive) {
                cleanupDuplicateSystemAlbums()
            }
            Button(localizer.text(.actionCancel), role: .cancel) { }
        } message: {
            Text(localizer.text(.collectionCleanupMessage))
        }
        .onChange(of: showSyncPrompt) { isPresented in
            if !isPresented, pendingSyncAlbumID != nil, !isSystemSyncEnabled {
                declineSystemSync()
            }
        }
    }

    private var collectionListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if shouldShowCleanupBanner {
                    cleanupBanner
                }
                searchRow

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredAlbums) { album in
                        CollectionAlbumCard(
                            album: album,
                            coverAssetID: resolvedCoverAssetID(for: album),
                            onRename: { openRenameModal(for: album) },
                            onDelete: { requestDeleteAlbum(album) },
                            onCustomizeCover: { openCoverPicker(for: album) }
                        )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedAlbum = album
                                }
                            }
                    }
                }
                .padding(.bottom, 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(localizer.text(.collectionSearchPlaceholder), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.primaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )

            Button(action: openNewAlbumModal) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text(localizer.text(.collectionNewButton))
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(.primary)
                .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var shouldShowCleanupBanner: Bool {
        isSystemSyncEnabled && !duplicateSystemAlbumIDs.isEmpty
    }

    private var cleanupBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.text(.collectionCleanupTitle))
                    .font(.subheadline.weight(.semibold))
                Text(localizer.text(.collectionCleanupMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: { showCleanupConfirmation = true }) {
                HStack(spacing: 6) {
                    if isCleaningDuplicates {
                        ProgressView()
                            .tint(.orange)
                    }
                    Text(localizer.text(.collectionCleanupAction))
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.primaryControlFill, in: Capsule())
            }
            .disabled(isCleaningDuplicates)
        }
        .padding(12)
        .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.dividerColor, lineWidth: 1)
        )
    }

    private var deleteAlbumModalView: some View {
        VStack(spacing: 16) {
            Text(localizer.text(.collectionDeleteTitle))
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(localizer.text(.collectionDeleteMessage))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(localizer.text(.actionCancel), action: closeDeleteModal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(localizer.text(.actionDelete), action: confirmDeleteAlbum)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var renameAlbumModalView: some View {
        VStack(spacing: 16) {
            Text(localizer.text(.collectionRenameTitle))
                .font(.headline)

            TextField(localizer.text(.collectionRenamePlaceholder), text: $renameText)
                .textInputAutocapitalization(.words)
                .onChange(of: renameText) { _ in
                    renameError = nil
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.primaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.dividerColor, lineWidth: 1)
                )

            if let renameError {
                Text(renameError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(localizer.text(.actionCancel), action: closeRenameModal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(localizer.text(.actionDone), action: confirmRenameAlbum)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var newAlbumModalView: some View {
        VStack(spacing: 16) {
            Text(localizer.text(.collectionNewModalTitle))
                .font(.headline)

            Text(localizer.text(.collectionNewModalMessage))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                TextField(localizer.text(.collectionNewModalPlaceholder), text: $newAlbumName)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.primaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.dividerColor, lineWidth: 1)
            )

            HStack(spacing: 12) {
                Button(localizer.text(.collectionNewModalCancel), action: closeNewAlbumModal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.secondaryControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(localizer.text(.collectionNewModalCreate), action: createAlbum)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#6F86C9"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func openNewAlbumModal() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showNewAlbumModal = true
        }
    }

    private func closeNewAlbumModal() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showNewAlbumModal = false
        }
    }

    private func closeActiveModal() {
        if showNewAlbumModal {
            closeNewAlbumModal()
        } else if showRenameModal {
            closeRenameModal()
        } else if showDeleteConfirmation {
            closeDeleteModal()
        }
    }

    private func openRenameModal(for album: CollectionAlbum) {
        pendingRenameAlbum = album
        renameText = album.title
        renameError = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showRenameModal = true
        }
    }

    private func closeRenameModal() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showRenameModal = false
        }
        pendingRenameAlbum = nil
        renameError = nil
    }

    private func confirmRenameAlbum() {
        guard let album = pendingRenameAlbum else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameError = localizer.text(.collectionRenameEmptyError)
            return
        }
        let normalized = normalizedTitle(trimmed)
        if normalized == normalizedTitle(album.title) {
            closeRenameModal()
            return
        }
        if albums.first(where: { normalizedTitle($0.title) == normalized && $0.id != album.id }) != nil {
            renameError = localizer.text(.collectionRenameDuplicateError)
            return
        }
        renameError = nil
        applyRename(album: album, newTitle: trimmed)
        closeRenameModal()
    }

    private func applyRename(album: CollectionAlbum, newTitle: String) {
        let oldTitle = album.title
        let oldCoverKey = coverKey(title: oldTitle, systemID: album.systemCollectionID)
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums[index].title = newTitle
            if selectedAlbum?.id == album.id {
                selectedAlbum = albums[index]
            }
        }
        let newCoverKey = coverKey(title: newTitle, systemID: album.systemCollectionID)
        coverStore.moveCover(from: oldCoverKey, to: newCoverKey)
        categoryStore.renameCategory(from: oldTitle, to: newTitle)
        albums = dedupeAlbumsByTitle(albums)

        if album.hasSystemCollection {
            renameSystemAlbum(albumID: album.systemCollectionID, newTitle: newTitle)
        }
    }

    private func requestDeleteAlbum(_ album: CollectionAlbum) {
        pendingDeleteAlbum = album
        withAnimation(.easeInOut(duration: 0.2)) {
            showDeleteConfirmation = true
        }
    }

    private func closeDeleteModal() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDeleteConfirmation = false
        }
        pendingDeleteAlbum = nil
    }

    private func confirmDeleteAlbum() {
        guard let album = pendingDeleteAlbum else { return }
        pendingDeleteAlbum = nil
        showDeleteConfirmation = false
        if album.hasSystemCollection {
            deleteSystemAlbum(album)
        } else {
            removeAlbum(album)
        }
    }

    private func removeAlbum(_ album: CollectionAlbum) {
        coverStore.removeCover(for: coverKey(for: album))
        albums.removeAll { $0.id == album.id }
        if selectedAlbum?.id == album.id {
            selectedAlbum = nil
        }
        if pendingSyncAlbumID == album.id {
            pendingSyncAlbumID = nil
        }
        categoryStore.removeCategoryIfNeeded(album.title)
    }

    private func deleteSystemAlbum(_ album: CollectionAlbum) {
        guard let systemID = album.systemCollectionID else {
            removeAlbum(album)
            return
        }
        requestPhotoAuthorization { granted in
            guard granted else { return }
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [systemID], options: nil)
            guard let collection = collections.firstObject else {
                removeAlbum(album)
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
            }) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        removeAlbum(album)
                        loadSystemAlbums()
                    }
                }
            }
        }
    }

    private func renameSystemAlbum(albumID: String?, newTitle: String) {
        guard let albumID else { return }
        requestPhotoAuthorization { granted in
            guard granted else { return }
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil)
            guard let collection = collections.firstObject else { return }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest(for: collection)
                request?.title = newTitle
            }) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        loadSystemAlbums()
                    }
                }
            }
        }
    }

    private func updateDuplicateSystemAlbums(from systemAlbums: [CollectionAlbum]) {
        var duplicates = Set<String>()
        let grouped = Dictionary(grouping: systemAlbums) { normalizedTitle($0.title) }
        let preferredByTitle: [String: String] = {
            var map: [String: String] = [:]
            for album in albums {
                guard let systemID = album.systemCollectionID else { continue }
                map[normalizedTitle(album.title)] = systemID
            }
            return map
        }()

        for (key, albums) in grouped {
            guard albums.count > 1 else { continue }
            let nonEmpty = albums.filter { $0.assetCount > 0 }
            if let keepAlbum = nonEmpty.max(by: { $0.assetCount < $1.assetCount }) {
                albums.filter { $0.assetCount == 0 }.forEach { album in
                    if let id = album.systemCollectionID {
                        duplicates.insert(id)
                    }
                }
                if let keepID = keepAlbum.systemCollectionID {
                    duplicates.remove(keepID)
                }
                continue
            }

            let keepID = preferredByTitle[key] ?? albums.compactMap(\.systemCollectionID).first
            albums.compactMap(\.systemCollectionID).forEach { id in
                if id != keepID {
                    duplicates.insert(id)
                }
            }
        }

        duplicateSystemAlbumIDs = Array(duplicates).sorted()
    }

    private func cleanupDuplicateSystemAlbums() {
        let ids = duplicateSystemAlbumIDs
        guard !ids.isEmpty else { return }
        isCleaningDuplicates = true
        requestPhotoAuthorization { granted in
            guard granted else {
                isCleaningDuplicates = false
                return
            }
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: ids, options: nil)
            var toDelete: [PHAssetCollection] = []
            collections.enumerateObjects { collection, _, _ in
                toDelete.append(collection)
            }
            guard !toDelete.isEmpty else {
                isCleaningDuplicates = false
                duplicateSystemAlbumIDs.removeAll()
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.deleteAssetCollections(toDelete as NSArray)
            }) { success, _ in
                DispatchQueue.main.async {
                    isCleaningDuplicates = false
                    if success {
                        duplicateSystemAlbumIDs.removeAll()
                        loadSystemAlbums()
                    }
                }
            }
        }
    }

    private func createAlbum() {
        let trimmed = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? localizer.text(.collectionNewDefaultTitle) : trimmed
        let normalized = normalizedTitle(title)
        if let existingIndex = albums.firstIndex(where: { normalizedTitle($0.title) == normalized }) {
            let existing = albums[existingIndex]
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedAlbum = existing
                newAlbumName = ""
                showNewAlbumModal = false
            }
            if isSystemSyncEnabled && existing.systemCollectionID == nil {
                bindOrCreateSystemAlbum(for: existing.id)
            }
            return
        }

        let newAlbum = CollectionAlbum(title: title)

        withAnimation(.easeInOut(duration: 0.25)) {
            albums.insert(newAlbum, at: 0)
            if demoAlbumsEnabled && !hasInjectedDemoAlbums && !isSystemSyncEnabled {
                albums.append(contentsOf: demoAlbums())
                hasInjectedDemoAlbums = true
            }
            selectedAlbum = newAlbum
            newAlbumName = ""
            showNewAlbumModal = false
        }
        categoryStore.addCategoryIfNeeded(title)

        if isSystemSyncEnabled {
            bindOrCreateSystemAlbum(for: newAlbum.id)
        } else if !didDeclineSystemSync {
            pendingSyncAlbumID = newAlbum.id
            showSyncPrompt = true
        }
    }

    private func demoAlbums() -> [CollectionAlbum] {
        let titles = [
            localizer.text(.demoCollectionTitleOne),
            localizer.text(.demoCollectionTitleTwo),
            localizer.text(.demoCollectionTitleThree)
        ]
        let photoSets = [demoPhotoSetA, demoPhotoSetB, demoPhotoSetC]
        return zip(titles, photoSets).map { title, photos in
            CollectionAlbum(title: title, demoPhotos: photos, isDemo: true)
        }
    }

    private var demoPhotoSetA: [CollectionDemoPhoto] {
        makeDemoPhotos(colors: [
            Color(hex: "#F8D5C2"),
            Color(hex: "#F3B39E"),
            Color(hex: "#F08A6B"),
            Color(hex: "#E86A5D")
        ])
    }

    private var demoPhotoSetB: [CollectionDemoPhoto] {
        makeDemoPhotos(colors: [
            Color(hex: "#BBD9F5"),
            Color(hex: "#C7B6F2"),
            Color(hex: "#F0B3D1"),
            Color(hex: "#F5D7A1")
        ])
    }

    private var demoPhotoSetC: [CollectionDemoPhoto] {
        makeDemoPhotos(colors: [
            Color(hex: "#B7E3D0"),
            Color(hex: "#86D0B2"),
            Color(hex: "#5FB994"),
            Color(hex: "#3A8F75")
        ])
    }

    private func makeDemoPhotos(colors: [Color]) -> [CollectionDemoPhoto] {
        let total = 12
        return (0..<total).map { index in
            CollectionDemoPhoto(color: colors[index % colors.count])
        }
    }

    private func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func dedupeAlbumsByTitle(_ input: [CollectionAlbum]) -> [CollectionAlbum] {
        var seen: [String: CollectionAlbum] = [:]
        var order: [String] = []

        for album in input {
            let key = normalizedTitle(album.title)
            if let existing = seen[key] {
                seen[key] = preferredAlbum(existing, album)
            } else {
                seen[key] = album
                order.append(key)
            }
        }

        return order.compactMap { seen[$0] }
    }

    private func preferredAlbum(_ lhs: CollectionAlbum, _ rhs: CollectionAlbum) -> CollectionAlbum {
        if lhs.assetCount != rhs.assetCount {
            return lhs.assetCount > rhs.assetCount ? lhs : rhs
        }
        if lhs.hasSystemCollection != rhs.hasSystemCollection {
            return lhs.hasSystemCollection ? lhs : rhs
        }
        return lhs
    }

    private func loadSystemAlbumsIfNeeded() {
        guard isSystemSyncEnabled, !hasLoadedSystemAlbums else { return }
        requestPhotoAuthorization { granted in
            guard granted else { return }
            loadSystemAlbums()
        }
    }

    private func startSystemSync(creatingAlbumID: String? = nil) {
        guard !isSyncingSystemAlbums else { return }
        isSyncingSystemAlbums = true
        requestPhotoAuthorization { granted in
            isSyncingSystemAlbums = false
            guard granted else { return }
            isSystemSyncEnabled = true
            didDeclineSystemSync = false
            loadSystemAlbums()
            if let albumID = creatingAlbumID {
                bindOrCreateSystemAlbum(for: albumID)
            }
        }
    }

    private func confirmSystemSync() {
        let albumID = pendingSyncAlbumID
        pendingSyncAlbumID = nil
        startSystemSync(creatingAlbumID: albumID)
    }

    private func declineSystemSync() {
        didDeclineSystemSync = true
        pendingSyncAlbumID = nil
    }

    private func requestPhotoAuthorization(_ completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
            return
        }
        completion(false)
    }

    private func loadSystemAlbums() {
        let systemAlbums = fetchSystemAlbums()
        updateAlbums(with: systemAlbums)
        syncCategoryStore(with: systemAlbums)
        updateDuplicateSystemAlbums(from: systemAlbums)
        hasLoadedSystemAlbums = true
    }

    private func fetchSystemAlbums() -> [CollectionAlbum] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )

        let assetOptions = PHFetchOptions()
        assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var results: [CollectionAlbum] = []
        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
            let title = collection.localizedTitle?.isEmpty == false
                ? (collection.localizedTitle ?? localizer.text(.collectionUntitledSystemAlbum))
                : localizer.text(.collectionUntitledSystemAlbum)
            let album = CollectionAlbum(
                id: collection.localIdentifier,
                title: title,
                demoPhotos: [],
                systemCollectionID: collection.localIdentifier,
                coverAssetID: assets.firstObject?.localIdentifier,
                assetCount: assets.count,
                isDemo: false
            )
            results.append(album)
        }
        return results
    }

    private func updateAlbums(with systemAlbums: [CollectionAlbum]) {
        let localAlbums = albums.filter { !$0.isDemo && !$0.hasSystemCollection }
        let syncedAlbums = albums.filter { $0.hasSystemCollection }
        let systemByID: [String: CollectionAlbum] = Dictionary(uniqueKeysWithValues: systemAlbums.compactMap { album in
            guard let id = album.systemCollectionID else { return nil }
            return (id, album)
        })

        var systemByTitle: [String: CollectionAlbum] = [:]
        for album in systemAlbums {
            let key = normalizedTitle(album.title)
            if let existing = systemByTitle[key] {
                if album.assetCount > existing.assetCount {
                    systemByTitle[key] = album
                }
            } else {
                systemByTitle[key] = album
            }
        }
        let titlesWithNonEmpty = Set(systemAlbums.filter { $0.assetCount > 0 }.map { normalizedTitle($0.title) })

        let updatedSynced = syncedAlbums.map { album -> CollectionAlbum in
            guard let id = album.systemCollectionID else { return album }
            var updated = album
            if let systemAlbum = systemByID[id] {
                updated.title = systemAlbum.title
                updated.coverAssetID = systemAlbum.coverAssetID
                updated.assetCount = systemAlbum.assetCount
            }
            let key = normalizedTitle(updated.title)
            if updated.assetCount == 0,
               let bestAlbum = systemByTitle[key],
               bestAlbum.assetCount > 0,
               bestAlbum.systemCollectionID != updated.systemCollectionID {
                updated.title = bestAlbum.title
                updated.systemCollectionID = bestAlbum.systemCollectionID
                updated.coverAssetID = bestAlbum.coverAssetID
                updated.assetCount = bestAlbum.assetCount
            }
            return updated
        }

        var consumedSystemIDs = Set(updatedSynced.compactMap(\.systemCollectionID))
        var resolvedLocal: [CollectionAlbum] = []

        for local in localAlbums {
            let key = normalizedTitle(local.title)
            if let match = systemByTitle[key],
               let systemID = match.systemCollectionID,
               !consumedSystemIDs.contains(systemID) {
                var merged = local
                merged.title = match.title
                merged.systemCollectionID = systemID
                merged.coverAssetID = match.coverAssetID
                merged.assetCount = match.assetCount
                merged.isDemo = false
                resolvedLocal.append(merged)
                consumedSystemIDs.insert(systemID)
            } else {
                resolvedLocal.append(local)
            }
        }

        let remainingSystemAlbums = systemAlbums.filter { album in
            guard let id = album.systemCollectionID else { return true }
            if consumedSystemIDs.contains(id) {
                return false
            }
            if album.assetCount == 0,
               titlesWithNonEmpty.contains(normalizedTitle(album.title)) {
                return false
            }
            return true
        }

        let merged = resolvedLocal + updatedSynced + remainingSystemAlbums
        albums = dedupeAlbumsByTitle(merged)
        if let selected = selectedAlbum {
            if let refreshed = albums.first(where: { $0.id == selected.id }) {
                selectedAlbum = refreshed
            } else {
                selectedAlbum = nil
            }
        }
    }

    private func syncCategoryStore(with systemAlbums: [CollectionAlbum]) {
        for album in systemAlbums {
            categoryStore.addCategoryIfNeeded(album.title)
        }
    }

    private func syncCategoryStoreFromAlbums() {
        let defaultName = FavoriteCategoryStore.localizedDefaultName(for: appLanguage)
        for album in albums where !album.isDemo {
            let trimmed = album.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if FavoriteCategoryStore.isDefaultCategoryName(trimmed) || trimmed == defaultName {
                continue
            }
            categoryStore.addCategoryIfNeeded(trimmed)
        }
    }

    private func syncAlbumsFromCategories(_ categories: [String]) {
        let existingTitles = Set(albums.map { normalizedTitle($0.title) })
        let defaultName = FavoriteCategoryStore.localizedDefaultName(for: appLanguage)
        var newAlbums: [CollectionAlbum] = []

        for name in categories {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if FavoriteCategoryStore.isDefaultCategoryName(trimmed) || trimmed == defaultName {
                continue
            }
            if existingTitles.contains(normalizedTitle(trimmed)) {
                continue
            }
            newAlbums.append(CollectionAlbum(title: trimmed))
        }

        if !newAlbums.isEmpty {
            albums.append(contentsOf: newAlbums)
            albums = dedupeAlbumsByTitle(albums)
            if isSystemSyncEnabled {
                newAlbums.forEach { bindOrCreateSystemAlbum(for: $0.id) }
            }
        }
    }

    private func bindOrCreateSystemAlbum(for albumID: String) {
        guard let album = albums.first(where: { $0.id == albumID }) else { return }
        guard album.systemCollectionID == nil else { return }
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
                PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else { return }
        let normalized = normalizedTitle(album.title)
        if pendingSystemAlbumTitles.contains(normalized) {
            return
        }

        if bindToExistingSystemAlbum(named: album.title, albumID: albumID) {
            return
        }

        createSystemAlbum(for: albumID, title: album.title)
    }

    private func bindToExistingSystemAlbum(named title: String, albumID: String) -> Bool {
        let searchTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localizedTitle =[c] %@", searchTitle)
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: fetchOptions
        )
        let assetOptions = PHFetchOptions()
        assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var bestCollection: PHAssetCollection?
        var bestAssets: PHFetchResult<PHAsset>?
        var bestCount = -1

        collections.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
            if assets.count > bestCount {
                bestCollection = collection
                bestAssets = assets
                bestCount = assets.count
            }
        }

        guard let collection = bestCollection, let assets = bestAssets else { return false }
        let coverAssetID = assets.firstObject?.localIdentifier

        DispatchQueue.main.async {
            pendingSystemAlbumTitles.remove(normalizedTitle(searchTitle))
            if let index = albums.firstIndex(where: { $0.id == albumID }) {
                albums[index].systemCollectionID = collection.localIdentifier
                albums[index].assetCount = assets.count
                albums[index].coverAssetID = coverAssetID
                albums[index].title = collection.localizedTitle ?? searchTitle
                if selectedAlbum?.id == albumID {
                    selectedAlbum = albums[index]
                }
            }
        }
        return true
    }

    private func createSystemAlbum(for albumID: String, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedTitle(trimmedTitle)
        pendingSystemAlbumTitles.insert(normalized)
        var placeholderID: String?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: trimmedTitle)
            placeholderID = request.placeholderForCreatedAssetCollection.localIdentifier
        }) { success, _ in
            DispatchQueue.main.async {
                pendingSystemAlbumTitles.remove(normalized)
                guard success, let placeholderID else { return }
                if let index = albums.firstIndex(where: { $0.id == albumID }) {
                    albums[index].systemCollectionID = placeholderID
                    albums[index].assetCount = 0
                    albums[index].coverAssetID = nil
                    if selectedAlbum?.id == albumID {
                        selectedAlbum = albums[index]
                    }
                }
            }
        }
    }

    private func resolvedCoverAssetID(for album: CollectionAlbum) -> String? {
        coverStore.coverAssetID(for: coverKey(for: album)) ?? album.coverAssetID
    }

    private func coverKey(for album: CollectionAlbum) -> String {
        coverKey(title: album.title, systemID: album.systemCollectionID)
    }

    private func coverKey(title: String, systemID: String?) -> String {
        if let systemID {
            return "system:\(systemID)"
        }
        return "local:\(normalizedTitle(title))"
    }

    private func openCoverPicker(for album: CollectionAlbum) {
        coverPickerAlbum = album
    }
}

private struct CollectionAlbumCard: View {
    let album: CollectionAlbum
    let coverAssetID: String?
    let onRename: () -> Void
    let onDelete: () -> Void
    let onCustomizeCover: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer

    @State private var coverImage: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private let imageManager = PHCachingImageManager()
    private let coverCornerRadius: CGFloat = 16

    private var coverColors: [Color] {
        Array(album.demoPhotos.prefix(2).map(\.color))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverView

            HStack(spacing: 8) {
                Text(album.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Menu {
                    Button(localizer.text(.collectionCoverCustomizeAction)) {
                        onCustomizeCover()
                    }
                    Button(localizer.text(.collectionRenameAction)) {
                        onRename()
                    }
                    Button(localizer.text(.actionDelete), role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            Text(localizer.albumItemsCount(album.photoCount))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.folderCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.folderCardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
        )
        .onAppear(perform: loadCoverIfNeeded)
        .task(id: coverAssetID) {
            loadCoverIfNeeded()
        }
        .onChange(of: coverAssetID) { _ in
            coverImage = nil
            loadCoverIfNeeded()
        }
        .onDisappear(perform: cancel)
    }

    private var coverView: some View {
        GeometryReader { proxy in
            let side = proxy.size.width

            ZStack {
                RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                    .fill(theme.mediaPlaceholderBackground)

                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else if coverColors.isEmpty {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                } else if coverColors.count == 1 {
                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                        .fill(coverColors[0])
                } else {
                    RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: coverColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func loadCoverIfNeeded() {
        guard coverImage == nil else { return }
        guard let coverAssetID else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [coverAssetID], options: nil)
        guard let asset = assets.firstObject else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 360, height: 360),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            guard let result else { return }
            DispatchQueue.main.async {
                coverImage = result
            }
        }
    }

    private func cancel() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}

private struct CollectionDetailView: View {
    let album: CollectionAlbum
    let onBack: () -> Void
    let onReturnHome: () -> Void
    @Binding var isPreviewing: Bool
    @Environment(\.localizer) private var localizer
    @Environment(\.appTheme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    @State private var systemItems: [AlbumMediaItem] = []
    @State private var isLoadingSystemItems = false
    @State private var previewItemID: String?
    @State private var previewItems: [AlbumMediaItem] = []

    var body: some View {
        VStack(spacing: 0) {
            header

            if album.hasSystemCollection {
                systemAlbumContent
            } else if album.demoPhotos.isEmpty {
                CollectionDetailEmptyStateView(onReturnHome: {
                    onBack()
                    onReturnHome()
                })
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(album.demoPhotos) { photo in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(photo.color)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(theme.contentBackground)
        .fullScreenCover(
            isPresented: Binding(
                get: { previewItemID != nil },
                set: { isPresented in
                    if !isPresented {
                        closePreview()
                    }
                }
            )
        ) {
            AlbumPreviewView(
                items: previewItems,
                selectedItemID: $previewItemID,
                currentTab: .collections,
                onClose: closePreview,
                onFavorite: { _ in closePreview() },
                onMoveToTrash: { _ in closePreview() },
                onInsertNewItem: { _ in closePreview() }
            )
        }
        .onAppear(perform: loadSystemItemsIfNeeded)
        .onChange(of: album.systemCollectionID) { _ in
            loadSystemItemsIfNeeded()
        }
        .onDisappear {
            isPreviewing = false
        }
    }

    @ViewBuilder
    private var systemAlbumContent: some View {
        if isLoadingSystemItems {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if systemItems.isEmpty {
            CollectionDetailEmptyStateView(onReturnHome: {
                onBack()
                onReturnHome()
            })
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(systemItems) { item in
                        AlbumGridTile(
                            item: item,
                            isSelected: false,
                            selectionMode: false
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            previewItems = systemItems
                            previewItemID = item.id
                            isPreviewing = true
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 100)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: {
                    closePreview()
                    onBack()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(localizer.text(.collectionDetailBackButton))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                }

                Spacer()

                Text(localizer.albumItemsCount(album.photoCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(album.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func closePreview() {
        previewItemID = nil
        isPreviewing = false
    }

    private func loadSystemItemsIfNeeded() {
        guard album.hasSystemCollection else { return }
        guard let id = album.systemCollectionID else { return }
        let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
        guard let collection = collections.firstObject else { return }
        isLoadingSystemItems = true
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        var items: [AlbumMediaItem] = []
        items.reserveCapacity(assets.count)
        assets.enumerateObjects { asset, _, _ in
            items.append(AlbumMediaItem(asset: asset, compressedSizeBytes: nil))
        }
        systemItems = items
        previewItems = items
        if let activeID = previewItemID,
           !items.contains(where: { $0.id == activeID }) {
            previewItemID = nil
            isPreviewing = false
        }
        isLoadingSystemItems = false
    }
}

private struct CollectionCoverPickerView: View {
    let album: CollectionAlbum
    let initialSelection: String?
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @Environment(\.localizer) private var localizer
    @Environment(\.appTheme) private var theme
    @State private var items: [AlbumMediaItem] = []
    @State private var selectedID: String?
    @State private var isLoading = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                theme.contentBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if items.isEmpty {
                    CollectionDetailEmptyStateView(onReturnHome: onCancel)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(items) { item in
                                ZStack(alignment: .topTrailing) {
                                    AlbumGridTile(
                                        item: item,
                                        isSelected: false,
                                        selectionMode: false
                                    )
                                    if selectedID == item.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(Color.accentColor)
                                            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                                            .padding(8)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedID = item.id
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(localizer.text(.collectionCoverPickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.text(.actionCancel)) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.text(.actionDone)) {
                        guard let selectedID else { return }
                        onSave(selectedID)
                    }
                    .disabled(selectedID == nil)
                }
            }
        }
        .onAppear(perform: loadItems)
    }

    private func loadItems() {
        selectedID = initialSelection
        guard album.hasSystemCollection, let id = album.systemCollectionID else {
            items = []
            return
        }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            fetchItems(collectionID: id)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        fetchItems(collectionID: id)
                    } else {
                        items = []
                    }
                }
            }
        } else {
            items = []
        }
    }

    private func fetchItems(collectionID: String) {
        let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil)
        guard let collection = collections.firstObject else {
            items = []
            return
        }
        isLoading = true
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        var result: [AlbumMediaItem] = []
        result.reserveCapacity(assets.count)
        assets.enumerateObjects { asset, _, _ in
            result.append(AlbumMediaItem(asset: asset, compressedSizeBytes: nil))
        }
        items = result
        isLoading = false
    }
}

final class CollectionCoverStore: ObservableObject {
    @Published private(set) var covers: [String: String]
    private let storageKey = "collection_custom_covers"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.dictionary(forKey: storageKey) as? [String: String] {
            covers = stored
        } else {
            covers = [:]
        }
    }

    func coverAssetID(for key: String) -> String? {
        covers[key]
    }

    func setCover(_ assetID: String, for key: String) {
        covers[key] = assetID
        save()
    }

    func removeCover(for key: String) {
        covers.removeValue(forKey: key)
        save()
    }

    func moveCover(from oldKey: String, to newKey: String) {
        guard oldKey != newKey else { return }
        guard let value = covers.removeValue(forKey: oldKey) else { return }
        covers[newKey] = value
        save()
    }

    private func save() {
        userDefaults.set(covers, forKey: storageKey)
    }
}

private struct CollectionEmptyStateView: View {
    let onCreate: () -> Void
    let onSync: () -> Void
    let isSyncing: Bool
    @Environment(\.localizer) private var localizer
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.secondaryControlFill)
                    .frame(width: 76, height: 76)

                Image(systemName: "folder.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }

            Text(localizer.text(.collectionEmptyTitle))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(localizer.text(.collectionEmptyMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text(localizer.text(.collectionEmptyAction))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#6F86C9"), in: Capsule())
            }
            .padding(.top, 4)

            Button(action: onSync) {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .tint(Color(hex: "#6F86C9"))
                    }
                    Text(localizer.text(.collectionEmptySyncAction))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#6F86C9"))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#6F86C9").opacity(0.35), lineWidth: 1)
                )
            }
            .disabled(isSyncing)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CollectionDetailEmptyStateView: View {
    let onReturnHome: () -> Void
    @Environment(\.localizer) private var localizer
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(theme.secondaryControlFill)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                )

            Text(localizer.text(.collectionDetailEmptyTitle))
                .font(.title3.weight(.bold))

            Text(localizer.text(.collectionDetailEmptyMessage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onReturnHome) {
                Text(localizer.text(.collectionDetailEmptyAction))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(theme.dividerColor, lineWidth: 1)
                    )
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AlbumCollectionCategory: Identifiable {
    let id: String
    let title: String
    let items: [AlbumMediaItem]
    let coverItems: [AlbumMediaItem]
    let lastUpdated: Date

    init(id: String, title: String, items: [AlbumMediaItem]) {
        self.id = id
        self.title = title
        let sortedItems = items.sorted { $0.updatedAt > $1.updatedAt }
        self.items = sortedItems
        self.coverItems = Array(sortedItems.prefix(3))
        self.lastUpdated = sortedItems.first?.updatedAt ?? .distantPast
    }

    var mediaCount: Int {
        items.count
    }
}

private struct AlbumCollectionBrowserView: View {
    let categories: [AlbumCollectionCategory]
    @Binding var activeCategoryID: String?
    let columns: [GridItem]
    let onPreview: (AlbumMediaItem, [AlbumMediaItem]) -> Void

    private var activeCategory: AlbumCollectionCategory? {
        guard let id = activeCategoryID else { return nil }
        return categories.first { $0.id == id }
    }

    private let folderColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        ZStack {
            if let activeCategory {
                AlbumCollectionDetailView(
                    category: activeCategory,
                    columns: columns,
                    onBack: { activeCategoryID = nil },
                    onPreview: onPreview
                )
                .transition(.move(edge: .trailing))
            } else if categories.isEmpty {
                AlbumCollectionEmptyState(messageKey: .albumCollectionEmptyTitle, showsHint: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity)
            } else {
                ScrollView {
                    LazyVGrid(columns: folderColumns, spacing: 16) {
                        ForEach(categories) { category in
                            AlbumCollectionFolderCard(category: category)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        activeCategoryID = category.id
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .leading))
            }
        }
        .onChange(of: categories.map(\.id)) { ids in
            if let activeID = activeCategoryID, !ids.contains(activeID) {
                activeCategoryID = nil
            }
        }
        .animation(.easeInOut(duration: 0.22), value: activeCategoryID)
    }
}

private struct AlbumCollectionFolderCard: View {
    let category: AlbumCollectionCategory
    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: "#6F86C9"))
                Spacer()
                Text(localizer.albumItemsCount(category.mediaCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(category.title)
                .font(.system(size: 18, weight: .semibold))

            Text(localizer.text(.albumFolderHint))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.folderCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.folderCardBorder, lineWidth: 1)
                )
        )
    }
}

private struct AlbumCollectionDetailView: View {
    let category: AlbumCollectionCategory
    let columns: [GridItem]
    let onBack: () -> Void
    let onPreview: (AlbumMediaItem, [AlbumMediaItem]) -> Void
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 0) {
            detailHeader

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(category.items) { item in
                        AlbumGridTile(
                            item: item,
                            isSelected: false,
                            selectionMode: false
                        )
                        .onTapGesture {
                            onPreview(item, category.items)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .overlay(
                AlbumCollectionEmptyState(messageKey: .albumCategoryEmptyMessage)
                    .opacity(category.items.isEmpty ? 1 : 0)
            )
        }
    }

    private var detailHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onBack()
                    }
                } label: {
                    Label(localizer.text(.albumCollectionBackButton), systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Text(localizer.albumMemoriesCount(category.mediaCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(category.title)
                    .font(.system(size: 24, weight: .bold))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

private struct AlbumCollectionEmptyState: View {
    var messageKey: L10n
    var showsHint: Bool = false
    @Environment(\.localizer) private var localizer

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "#6F86C9"))
            Text(localizer.text(messageKey))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            if showsHint {
                Text(localizer.text(.albumCollectionEmptyMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.top, 60)
    }
}

private struct AlbumGridTile: View {
    let item: AlbumMediaItem
    let isSelected: Bool
    let selectionMode: Bool

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private let imageManager = PHCachingImageManager()
    @Environment(\.appTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width

            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            theme.mediaPlaceholderBackground
                                .overlay(
                                    ProgressView()
                                        .tint(.secondary)
                                )
                        }
                    }
                    .frame(width: side, height: side)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if item.mediaType == .video {
                        videoBadge
                            .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .opacity(selectionMode && !isSelected ? 0.85 : 1)

                if let compressed = item.compressedSizeLabel {
                    Text(compressed)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                }

                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(10)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear(perform: loadImageIfNeeded)
        .onDisappear(perform: cancel)
    }

    private var videoBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "video.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(item.durationLabel ?? "")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55), in: Capsule())
        .shadow(radius: 2)
    }

    private func loadImageIfNeeded() {
        guard image == nil else { return }
        if let testImage = item.testImage?.image {
            image = testImage
            return
        }

        guard let asset = item.asset else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 450, height: 450),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                image = result
            }
        }
    }

    private func cancel() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}

private struct AlbumDetailView: View {
    let item: AlbumMediaItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.localizer) private var localizer
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID
    @State private var isCaptionVisible = true
    private let imageManager = PHCachingImageManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch item.mediaType {
                case .photo:
                    photoBody
                case .video:
                    videoBody
                }

                if let caption = captionText, isCaptionVisible {
                    CaptionOverlayView(text: caption)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(item.displayDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.text(.actionDone)) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard captionText != nil else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCaptionVisible.toggle()
                }
            }
        }
        .onAppear(perform: loadContent)
        .onDisappear(perform: cancel)
    }

    private var captionText: String? {
        let trimmed = item.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private var photoBody: some View {
        if let image {
            GeometryReader { geometry in
                let size = geometry.size
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: size.width, maxHeight: size.height)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    @ViewBuilder
    private var videoBody: some View {
        if let player {
            VideoPlayer(player: player)
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private func loadContent() {
        switch item.mediaType {
        case .photo:
            loadPhoto()
        case .video:
            loadVideo()
        }
    }

    private func loadPhoto() {
        if let testImage = item.testImage?.image {
            image = testImage
            return
        }

        guard let asset = item.asset else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            if let result {
                image = result
            }
        }
    }

    private func loadVideo() {
        guard let asset = item.asset else { return }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let avAsset else { return }
            let playerItem = AVPlayerItem(asset: avAsset)
            DispatchQueue.main.async {
                let player = AVPlayer(playerItem: playerItem)
                self.player = player
                player.play()
            }
        }
    }

    private func cancel() {
        if requestID != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
        player?.pause()
    }
}

private struct CaptionOverlayView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body.weight(.regular))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.65))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
    }
}
