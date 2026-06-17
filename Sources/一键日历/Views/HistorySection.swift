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
                // 搜索框
                TextField(NSLocalizedString("search_history", comment: ""), text: $viewModel.historySearchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .controlSize(.small)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredHistoryEntries.enumerated()), id: \.element.id) { index, entry in
                            HStack {
                                Button(action: {
                                    viewModel.selectHistoryEntry(entry)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.title)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                            Text(entry.baseDate.formattedChinese())
                                                .font(.caption)
                                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.left.circle")
                                            .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    deleteEntry(entry)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .help(NSLocalizedString("delete_history", comment: ""))
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

    private func deleteEntry(_ entry: HistoryEntry) {
        var entries = viewModel.historyEntries
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.remove(at: index)
            viewModel.historyEntries = entries
        }
    }
}
