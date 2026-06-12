import SwiftUI

struct HistorySection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("history_title", comment: ""))
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
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            if viewModel.historyEntries.isEmpty {
                Text(NSLocalizedString("no_history", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.historyEntries) { entry in
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
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.left.circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.vertical, 4)
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
    }
}