import SwiftUI

struct HistorySection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(NSLocalizedString("history_title", comment: ""), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                if !viewModel.historyEntries.isEmpty {
                    Button(NSLocalizedString("clear_history", comment: "")) {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                Button(action: {
                    viewModel.showHistory = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .buttonStyle(.borderless)
            }

            if viewModel.historyEntries.isEmpty {
                Text(NSLocalizedString("empty_history_hint", comment: ""))
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        .font(.caption)
                    TextField(NSLocalizedString("search_history", comment: ""), text: $viewModel.historySearchText)
                        .textFieldStyle(.plain)
                        .controlSize(.small)
                    if !viewModel.historySearchText.isEmpty {
                        Button(action: {
                            viewModel.historySearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.currentTheme.cardBackgroundColor)
                .cornerRadius(6)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredHistoryEntries.enumerated()), id: \.element.id) { index, entry in
                            HStack(alignment: .top, spacing: 8) {
                                Button(action: {
                                    viewModel.selectHistoryEntry(entry)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.title)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            HStack(spacing: 4) {
                                                Text(entry.baseDate.formattedChinese())
                                                    .font(.caption)
                                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                                Text("·")
                                                    .font(.caption)
                                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                                Text(scheduleTypeLabel(entry.type))
                                                    .font(.caption)
                                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                                Text("·")
                                                    .font(.caption)
                                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                                Text(String(format: NSLocalizedString("history_review_count", comment: ""), "\(entry.reviewDates.count)"))
                                                    .font(.caption)
                                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.left.circle")
                                            .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                VStack(spacing: 4) {
                                    if entry.createdEventIdentifiers.isEmpty {
                                        Text(NSLocalizedString("today_created_edit_unavailable", comment: ""))
                                            .font(.caption2)
                                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                            .frame(maxWidth: 72, alignment: .trailing)
                                    } else {
                                        Button(NSLocalizedString("today_created_edit_detail", comment: "")) {
                                            viewModel.beginSharedDetailEdit(for: entry)
                                        }
                                        .buttonStyle(.borderless)
                                        .controlSize(.small)
                                        .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                                    }

                                    Button(action: {
                                        deleteEntry(entry)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .help(NSLocalizedString("delete_history", comment: ""))
                                }
                            }
                            .padding(.vertical, 6)

                            if index < viewModel.filteredHistoryEntries.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func scheduleTypeLabel(_ type: HistoryEntry.ScheduleType) -> String {
        switch type {
        case .review: return NSLocalizedString("schedule_mode_review", comment: "")
        case .single: return NSLocalizedString("schedule_mode_single", comment: "")
        }
    }

    private func deleteEntry(_ entry: HistoryEntry) {
        viewModel.deleteHistoryEntry(entry)
    }
}
