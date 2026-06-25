import SwiftUI
import EventKit

struct SearchResultDetailView: View {
    @ObservedObject var viewModel: ReviewViewModel
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(NSLocalizedString("search_result_detail", comment: ""), systemImage: "info.circle")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.selectedSearchResult = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(event.title ?? NSLocalizedString("untitled", comment: ""))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.currentTheme.primaryTextColor)

                Divider()

                detailRow(
                    icon: "calendar",
                    label: NSLocalizedString("search_result_date", comment: ""),
                    value: event.startDate.formattedChinese()
                )

                if !event.isAllDay {
                    detailRow(
                        icon: "clock",
                        label: NSLocalizedString("search_result_time", comment: ""),
                        value: timeRangeString
                    )
                } else {
                    detailRow(
                        icon: "clock",
                        label: NSLocalizedString("search_result_time", comment: ""),
                        value: NSLocalizedString("all_day", comment: "")
                    )
                }

                detailRow(
                    icon: "calendar.badge.checkmark",
                    label: NSLocalizedString("search_result_calendar", comment: ""),
                    value: "\(event.calendar.source.title) → \(event.calendar.title)"
                )

                if let notes = event.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(NSLocalizedString("search_result_notes", comment: ""), systemImage: "text.alignleft")
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(viewModel.currentTheme.primaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(viewModel.currentTheme.cardBackgroundColor)
            .cornerRadius(8)

            Spacer(minLength: 0)
        }
        .padding()
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(viewModel.currentTheme.primaryTextColor)
            }
        }
    }

    private var timeRangeString: String {
        let start = event.startDate.formattedTime()
        let end = event.endDate.formattedTime()
        return "\(start) – \(end)"
    }
}
