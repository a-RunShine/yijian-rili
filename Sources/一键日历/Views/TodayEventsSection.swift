import SwiftUI

struct TodayEventsSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            daySwitcher

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .font(.caption)
                TextField(NSLocalizedString("today_search_placeholder", comment: ""), text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.performSearch()
                        if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            viewModel.showSearch = true
                        }
                    }
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.resetSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(viewModel.currentTheme.cardBackgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.25), lineWidth: 1)
            )

            if viewModel.displayedEvents.isEmpty {
                Text(viewModel.selectedDayType.emptyHint)
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewModel.currentTheme.cardBackgroundColor)
                    .cornerRadius(10)
            } else {
                ForEach(viewModel.displayedEvents) { event in
                    eventCard(event)
                }
            }
        }
    }

    private var daySwitcher: some View {
        HStack(spacing: 8) {
            ForEach(ReviewViewModel.DayType.allCases) { dayType in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDayType(dayType)
                    }
                } label: {
                    Text(dayType.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedDayType == dayType
                                ? (viewModel.currentTheme.primaryTextColor ?? Color(red: 0.071, green: 0.149, blue: 0.227))
                                : viewModel.currentTheme.cardBackgroundColor
                        )
                        .foregroundColor(
                            viewModel.selectedDayType == dayType
                                ? .white
                                : (viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    viewModel.selectedDayType == dayType
                                        ? Color.clear
                                        : (viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func eventCard(_ event: CalendarEventInfo) -> some View {
        let detail = NotesDetail.extract(event.notes)
        let status = viewModel.occurrenceStatus(for: event.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.beginSharedDetailEditFromBrowse(event)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: event.colorHex) ?? Color(red: 0.051, green: 0.580, blue: 0.533))
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(event.title.isEmpty ? NSLocalizedString("untitled", comment: "") : event.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.currentTheme.primaryTextColor)
                                .lineLimit(2)
                            if status != .unmarked {
                                Text(status == .done
                                      ? NSLocalizedString("occurrence_status_done", comment: "")
                                      : NSLocalizedString("occurrence_status_skipped", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background((viewModel.currentTheme.accentColor ?? .accentColor).opacity(0.12))
                                    .cornerRadius(4)
                            }
                            Spacer(minLength: 0)
                        }
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 4) {
                            Text(event.isAllDay ? NSLocalizedString("all_day", comment: "") : event.start.formattedTime())
                            Text("·")
                            Text((event.calendarTitle?.isEmpty == false)
                                 ? (event.calendarTitle ?? "")
                                 : NSLocalizedString("calendar_default_label", comment: ""))
                        }
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                occurrenceActionButton(
                    title: NSLocalizedString("occurrence_mark_done", comment: ""),
                    selected: status == .done
                ) {
                    viewModel.setOccurrenceStatus(
                        eventId: event.id,
                        status: status == .done ? .unmarked : .done
                    )
                }
                occurrenceActionButton(
                    title: NSLocalizedString("occurrence_mark_skipped", comment: ""),
                    selected: status == .skipped
                ) {
                    viewModel.setOccurrenceStatus(
                        eventId: event.id,
                        status: status == .skipped ? .unmarked : .skipped
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.2), lineWidth: 1)
        )
    }

    private func occurrenceActionButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    selected
                        ? (viewModel.currentTheme.accentColor ?? .accentColor).opacity(0.2)
                        : (viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.08)
                )
                .foregroundColor(
                    selected
                        ? (viewModel.currentTheme.accentColor ?? .accentColor)
                        : (viewModel.currentTheme.secondaryTextColor ?? .secondary)
                )
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
