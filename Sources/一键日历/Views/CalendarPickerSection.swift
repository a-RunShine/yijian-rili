import SwiftUI

struct CalendarPickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    var forceExpanded: Bool = false
    @AppStorage("calendarPickerExpanded") private var isExpanded: Bool = false

    private var expanded: Bool { forceExpanded || isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if forceExpanded {
                Text(NSLocalizedString("calendar_picker_title", comment: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .padding(.bottom, 8)
            } else {
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
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $viewModel.selectedCalendarIdentifier) {
                        Text(NSLocalizedString("calendar_default_label", comment: ""))
                            .tag("")
                        ForEach(groupedCalendars, id: \.sourceTitle) { group in
                            Section(group.sourceTitle) {
                                ForEach(group.calendars) { calendar in
                                    Text(calendar.title)
                                        .tag(calendar.identifier)
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
                .padding(forceExpanded ? 12 : 0)
                .padding(.top, forceExpanded ? 0 : 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(forceExpanded ? viewModel.currentTheme.cardBackgroundColor : Color.clear)
                .cornerRadius(forceExpanded ? 10 : 0)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(forceExpanded ? 0 : 16)
        .background(forceExpanded ? Color.clear : viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }

    private struct CalendarGroup: Hashable {
        let sourceTitle: String
        let calendars: [CalendarInfo]
    }

    private var groupedCalendars: [CalendarGroup] {
        let grouped = Dictionary(grouping: viewModel.availableCalendars) { $0.sourceTitle }
        return grouped
            .map { CalendarGroup(sourceTitle: $0.key, calendars: $0.value) }
            .sorted { $0.sourceTitle < $1.sourceTitle }
    }
}
