import SwiftUI

struct HistoryDeleteSheet: View {
    @ObservedObject var viewModel: ReviewViewModel
    let entry: HistoryEntry

    private var memberCount: Int {
        entry.createdEventIdentifiers.count
    }

    private var reviewDayCount: Int {
        entry.reviewDates.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("history_delete_title", comment: ""))
                .font(.headline)

            Text(entry.title)
                .font(.subheadline)
                .lineLimit(2)

            Text(String(
                format: NSLocalizedString("history_delete_summary", comment: ""),
                "\(reviewDayCount)"
            ))
            .font(.caption)
            .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    viewModel.commitHistoryDelete(entry, scope: .recordOnly)
                } label: {
                    optionLabel(
                        title: NSLocalizedString("history_delete_record_only", comment: ""),
                        detail: NSLocalizedString("history_delete_record_only_hint", comment: "")
                    )
                }
                .buttonStyle(.borderless)

                Button {
                    viewModel.commitHistoryDelete(entry, scope: .eventsToo)
                } label: {
                    optionLabel(
                        title: NSLocalizedString("history_delete_events_too", comment: ""),
                        detail: memberCount > 0
                            ? String(
                                format: NSLocalizedString("history_delete_events_too_hint", comment: ""),
                                "\(memberCount)"
                            )
                            : NSLocalizedString("history_delete_events_too_unavailable", comment: "")
                    )
                }
                .buttonStyle(.borderless)
                .disabled(memberCount == 0)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(NSLocalizedString("history_delete_cancel", comment: "")) {
                    viewModel.cancelHistoryDelete()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 320)
    }

    private func optionLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
