import SwiftUI

struct SearchSheetView: View {
    @ObservedObject var viewModel: ReviewViewModel
    @FocusState private var isFieldFocused: Bool
    @State private var hitPendingDelete: SearchHit?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hit = viewModel.selectedSearchHit {
                Group {
                    detailHeader(for: hit)
                    SearchResultDetailView(viewModel: viewModel, event: hit.representative)
                    if hit.isSeries {
                        seriesMembersHint(hit)
                    }
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.selectedSearchHit?.id)
        .onAppear {
            isFieldFocused = viewModel.selectedSearchHit == nil
        }
        .alert(
            NSLocalizedString("search_delete_confirm_title", comment: ""),
            isPresented: Binding(
                get: { hitPendingDelete != nil },
                set: { if !$0 { hitPendingDelete = nil } }
            ),
            presenting: hitPendingDelete
        ) { hit in
            Button(NSLocalizedString("search_delete_cancel", comment: ""), role: .cancel) {
                hitPendingDelete = nil
            }
            Button(NSLocalizedString("search_delete_confirm_action", comment: ""), role: .destructive) {
                performDirectDelete(hit)
            }
        } message: { hit in
            Text(String(
                format: NSLocalizedString("search_delete_confirm_message", comment: ""),
                hit.title.isEmpty ? NSLocalizedString("untitled", comment: "") : hit.title
            ))
        }
        .sheet(item: $viewModel.seriesPendingDelete) { hit in
            SeriesDeleteSheet(viewModel: viewModel, hit: hit)
        }
    }

    private func performDirectDelete(_ hit: SearchHit) {
        hitPendingDelete = nil
        let success = viewModel.deleteSearchHit(hit)
        if success, viewModel.selectedSearchHit?.id == hit.id {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                viewModel.clearSearchSelection()
            }
        }
    }

    private func requestDelete(_ hit: SearchHit) {
        if hit.needsSelectiveDelete {
            viewModel.beginSeriesDelete(hit)
        } else {
            hitPendingDelete = hit
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

    private func detailHeader(for hit: SearchHit) -> some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.clearSearchSelection()
                }
            } label: {
                Label(NSLocalizedString("search_back", comment: ""), systemImage: "chevron.left")
                    .font(.headline)
            }
            .buttonStyle(.borderless)
            Spacer()
            Button {
                requestDelete(hit)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("search_delete_button", comment: ""))
            Button {
                viewModel.showSearch = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private func seriesMembersHint(_ hit: SearchHit) -> some View {
        Text(
            String(
                format: NSLocalizedString("series_search_member_count", comment: ""),
                "\(hit.members.count)"
            )
        )
        .font(.caption)
        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
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
                    viewModel.searchHits = []
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
            Text(String(format: NSLocalizedString("search_result_count", comment: ""), "\(viewModel.searchHits.count)"))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
        }

        if trimmed.isEmpty {
            Text(NSLocalizedString("search_empty_hint", comment: ""))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.searchHits.isEmpty {
            Text(NSLocalizedString("search_no_results", comment: ""))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.searchHits.enumerated()), id: \.element.id) { index, hit in
                        searchRow(hit)
                        if index < viewModel.searchHits.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func searchRow(_ hit: SearchHit) -> some View {
        let event = hit.representative
        return HStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewModel.selectSearchHit(hit)
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: event.colorHex) ?? (viewModel.currentTheme.accentColor ?? .accentColor))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.title.isEmpty ? NSLocalizedString("untitled", comment: "") : hit.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if hit.isSeries {
                                Text(
                                    String(
                                        format: NSLocalizedString("series_search_row_subtitle", comment: ""),
                                        "\(hit.members.count)"
                                    )
                                )
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                            } else {
                                Text(event.start.formattedChinese())
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
                                    Text(event.start.formattedTime())
                                        .font(.caption)
                                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                }
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
                requestDelete(hit)
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
