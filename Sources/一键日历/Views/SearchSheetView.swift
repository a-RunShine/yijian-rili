import SwiftUI
import EventKit

struct SearchSheetView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @FocusState private var isFieldFocused: Bool
    @State private var eventPendingDelete: EKEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let event = viewModel.selectedSearchResult {
                Group {
                    detailHeader
                    SearchResultDetailView(viewModel: viewModel, event: event)
                }
                .id("search-detail")
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                Group {
                    searchHeader
                    searchField
                    searchBody
                }
                .id("search-list")
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.selectedSearchResult)
        .onAppear {
            isFieldFocused = viewModel.selectedSearchResult == nil
        }
        .alert(
            NSLocalizedString("search_delete_confirm_title", comment: ""),
            isPresented: Binding(
                get: { eventPendingDelete != nil },
                set: { if !$0 { eventPendingDelete = nil } }
            ),
            presenting: eventPendingDelete
        ) { event in
            Button(NSLocalizedString("search_delete_cancel", comment: ""), role: .cancel) {
                eventPendingDelete = nil
            }
            Button(NSLocalizedString("search_delete_confirm_action", comment: ""), role: .destructive) {
                performDelete(event)
            }
        } message: { event in
            Text(String(
                format: NSLocalizedString("search_delete_confirm_message", comment: ""),
                event.title ?? NSLocalizedString("untitled", comment: "")
            ))
        }
    }

    private func performDelete(_ event: EKEvent) {
        eventPendingDelete = nil
        let success = viewModel.deleteSearchResult(event)
        if success, viewModel.selectedSearchResult?.eventIdentifier == event.eventIdentifier {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                viewModel.selectedSearchResult = nil
            }
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.selectedSearchResult = nil
                }
            } label: {
                Label(NSLocalizedString("search_back", comment: ""), systemImage: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.borderless)
            Spacer()
            if let event = viewModel.selectedSearchResult {
                Button {
                    eventPendingDelete = event
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("search_delete_button", comment: ""))
            }
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
    }

    private func searchRow(_ event: EKEvent) -> some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.selectedSearchResult = event
                }
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                eventPendingDelete = event
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("search_delete_button", comment: ""))
        }
        .padding(.vertical, 6)
    }
}
