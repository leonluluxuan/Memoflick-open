//
//  MonthFilterView.swift
//  memoflick
//
//  Created by Codex on 2025/11/26.
//

import SwiftUI

struct MonthFilterView: View {
    @Binding var photoFilter: MediaTimeFilter
    @Binding var videoFilter: MediaTimeFilter
    let availableMonths: [YearMonth: Int]
    let isLoading: Bool

    @State private var selected: YearMonth?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.localizer) private var localizer

    var body: some View {
        List {
            if isLoading && availableMonths.isEmpty {
                loadingRow
            } else if availableMonths.isEmpty {
                emptyRow
            } else {
                monthSection
            }
        }
        .navigationTitle(localizer.text(.timeFilterNavigationTitle))
        .onAppear { syncSelectionFromFilter() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(localizer.text(.actionClearToRandom)) {
                    selected = nil
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(localizer.text(.actionDone)) {
                    applySelection()
                    dismiss()
                }
            }
        }
        .background(theme.rootBackground)
    }
}

private extension MonthFilterView {
    var sortedMonths: [(YearMonth, Int)] {
        availableMonths
            .sorted { lhs, rhs in
                if lhs.key.year == rhs.key.year {
                    return lhs.key.month > rhs.key.month
                }
                return lhs.key.year > rhs.key.year
            }
    }

    var monthSection: some View {
        Section {
            ForEach(sortedMonths, id: \.0) { item in
                let month = item.0
                let count = item.1
                Button {
                    toggle(month)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(monthLabel(for: month))
                                .font(.body.weight(.medium))
                            Text(localizer.albumItemsCount(count))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected == month {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(isLoading ? localizer.text(.timeFilterLoadingTitle) : localizer.text(.timeFilterSectionTitle))
        }
    }

    var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(localizer.text(.timeFilterLoadingMessage))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    var emptyRow: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(localizer.text(.timeFilterEmptyMessage))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .listRowBackground(Color.clear)
    }

    func toggle(_ month: YearMonth) {
        if selected == month {
            selected = nil
        } else {
            selected = month
        }
    }

    func syncSelectionFromFilter() {
        switch photoFilter {
        case .all:
            selected = nil
        case let .months(months):
            selected = months.first
        }
    }

    func monthLabel(for month: YearMonth) -> String {
        switch localizer.language {
        case .english:
            return "\(month.month)/\(month.year)"
        case .simplifiedChinese:
            return "\(month.year)年\(month.month)月"
        }
    }

    func applySelection() {
        let newFilter: MediaTimeFilter = selected.map { .months([$0]) } ?? .all
        // 保持照片/视频使用同一套时间过滤
        photoFilter = newFilter
        videoFilter = newFilter
    }
}

#Preview {
    MonthFilterView(
        photoFilter: .constant(.all),
        videoFilter: .constant(.all),
        availableMonths: [
            YearMonth(year: 2024, month: 10): 42,
            YearMonth(year: 2023, month: 6): 8
        ],
        isLoading: false
    )
    .environment(\.appTheme, .dark)
    .environment(\.localizer, AppLocalizer(language: .simplifiedChinese))
}
