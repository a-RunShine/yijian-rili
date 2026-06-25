import SwiftUI
import EventKit

struct CalendarPickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @AppStorage("calendarPickerExpanded") private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(NSLocalizedString("calendar_picker_title", comment: ""), systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.selectedCalendarDisplayName)
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $viewModel.selectedCalendarIdentifier) {
                        Text(NSLocalizedString("calendar_default_label", comment: ""))
                            .tag("")
                        ForEach(groupedCalendars, id: \.sourceTitle) { group in
                            Section(group.sourceTitle) {
                                ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                    Text(calendar.title)
                                        .tag(calendar.calendarIdentifier)
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if viewModel.isSelectedCalendarLocal {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(NSLocalizedString("calendar_local_warning", comment: ""))
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    } else if !viewModel.hasCloudCalendar {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text(NSLocalizedString("calendar_no_cloud_hint", comment: ""))
                        }
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    } else {
                        Text(NSLocalizedString("calendar_picker_hint", comment: ""))
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }

    private struct CalendarGroup: Hashable {
        let sourceTitle: String
        let calendars: [EKCalendar]
    }

    private var groupedCalendars: [CalendarGroup] {
        let grouped = Dictionary(grouping: viewModel.availableCalendars) { $0.source.title }
        return grouped
            .map { CalendarGroup(sourceTitle: $0.key, calendars: $0.value) }
            .sorted { $0.sourceTitle < $1.sourceTitle }
    }
}
