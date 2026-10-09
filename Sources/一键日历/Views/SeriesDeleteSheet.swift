import SwiftUI

struct SeriesDeleteSheet: View {
    @ObservedObject var viewModel: ReviewViewModel
    let hit: SearchHit
    @State private var selectedIDs: Set<String>

    init(viewModel: ReviewViewModel, hit: SearchHit) {
        self.viewModel = viewModel
        self.hit = hit
        _selectedIDs = State(initialValue: Set(hit.members.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("series_delete_title", comment: ""))
                .font(.headline)
                .foregroundColor(viewModel.currentTheme.primaryTextColor)

            Text(
                String(
                    format: NSLocalizedString("series_delete_subtitle", comment: ""),
                    hit.title.isEmpty ? NSLocalizedString("untitled", comment: "") : hit.title
                )
            )
            .font(.caption)
            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(hit.members.enumerated()), id: \.element.id) { index, event in
                        Toggle(isOn: binding(for: event.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memberTitle(index: index, event: event))
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.currentTheme.primaryTextColor)
                                Text(event.start.formattedChinese())
                                    .font(.caption)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(.vertical, 8)
                        if index < hit.members.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            HStack {
                Button(NSLocalizedString("search_delete_cancel", comment: "")) {
                    viewModel.seriesPendingDelete = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(NSLocalizedString("series_delete_confirm", comment: "")) {
                    _ = viewModel.deleteSearchHitMembers(ids: Array(selectedIDs))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(selectedIDs.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 340, height: 360)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { on in
                if on {
                    selectedIDs.insert(id)
                } else {
                    selectedIDs.remove(id)
                }
            }
        )
    }

    private func memberTitle(index: Int, event: CalendarEventInfo) -> String {
        let key = NormalizeNotes.normalize(event.notes)
        if key.isEmpty {
            return String(
                format: NSLocalizedString("series_delete_member_fallback", comment: ""),
                "\(index + 1)"
            )
        }
        return key
    }
}
