import SwiftUI
import EventKit

struct SearchSheetView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let event = viewModel.selectedSearchResult {
                detailHeader
                SearchResultDetailView(viewModel: viewModel, event: event)
            } else {
                searchHeader
                searchField
                searchBody
            }
        }
        .padding()
        .onAppear {
            isFieldFocused = viewModel.selectedSearchResult == nil
        }
    }

    private var searchHeader: some View {
        HStack {
            Label(NSLocalizedString("search_sheet_title", comment: ""), systemImage: "magnifyingglass")
                .font(.headline)
            Spacer()
            Button {
                viewModel.showSearch = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private var detailHeader: some View {
        HStack {
            Button {
                viewModel.selectedSearchResult = nil
            } label: {
                Label(NSLocalizedString("search_back", comment: ""), systemImage: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.borderless)
            Spacer()
            Button {
                viewModel.showSearch = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .font(.caption)
            TextField(NSLocalizedString("search_placeholder", comment: ""), text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .controlSize(.small)
                .focused($isFieldFocused)
                .onSubmit {
                    viewModel.performSearch()
                }
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.searchResults = []
                    isFieldFocused = true
                } label: {
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
    }

    @ViewBuilder
    private var searchBody: some View {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Text(String(format: NSLocalizedString("search_result_count", comment: ""), "\(viewModel.searchResults.count)"))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
        }

        if trimmed.isEmpty {
            Text(NSLocalizedString("search_empty_hint", comment: ""))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.searchResults.isEmpty {
            Text(NSLocalizedString("search_no_results", comment: ""))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { index, event in
                        searchRow(event)
                        if index < viewModel.searchResults.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }

        Spacer(minLength: 0)
    }

    private func searchRow(_ event: EKEvent) -> some View {
        Button {
            viewModel.selectedSearchResult = event
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? NSLocalizedString("untitled", comment: ""))
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(event.startDate.formattedChinese())
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        if event.isAllDay {
                            Text(NSLocalizedString("all_day", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        } else {
                            Text(event.startDate.formattedTime())
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
