import SwiftUI

struct TodayEventsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var isExpanded = false

    private let collapsedLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(viewModel.selectedDayType.sectionTitle, systemImage: "sun.max")
                    .font(.headline)
                Spacer(minLength: 4)
                daySwitcher
            }

            if viewModel.displayedEvents.isEmpty {
                Text(viewModel.selectedDayType.emptyHint)
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            } else {
                let displayCount = isExpanded ? viewModel.displayedEvents.count : min(viewModel.displayedEvents.count, collapsedLimit)
                ForEach(Array(viewModel.displayedEvents.prefix(displayCount).enumerated()), id: \.offset) { index, event in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 6, height: 6)

                        if event.isAllDay {
                            Text(NSLocalizedString("all_day", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 40, alignment: .leading)
                        } else {
                            Text(event.startDate.formattedTime())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 40, alignment: .leading)
                        }
                        Text(event.title ?? NSLocalizedString("untitled", comment: ""))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(event.isAllDay ? (viewModel.currentTheme.secondaryTextColor ?? Color.secondary)?.opacity(0.06) : Color.clear)
                    .cornerRadius(4)

                    if index < displayCount - 1 {
                        Divider()
                    }
                }
                if viewModel.displayedEvents.count > collapsedLimit {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                            Text(isExpanded
                                 ? NSLocalizedString("collapse", comment: "")
                                 : String(format: NSLocalizedString("more_events", comment: ""), "\(viewModel.displayedEvents.count - collapsedLimit)"))
                                .font(.caption2)
                        }
                        .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }

    private var daySwitcher: some View {
        HStack(spacing: 2) {
            ForEach(ReviewViewModel.DayType.allCases) { dayType in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDayType(dayType)
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text(dayType.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(viewModel.date(for: dayType).formattedShort())
                            .font(.system(size: 9))
                            .opacity(0.75)
                    }
                    .frame(minWidth: 42)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 4)
                    .background(
                        viewModel.selectedDayType == dayType
                            ? (viewModel.currentTheme.accentColor ?? .accentColor)
                            : Color.clear
                    )
                    .foregroundColor(
                        viewModel.selectedDayType == dayType
                            ? .white
                            : (viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    )
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.1))
        .cornerRadius(7)
    }
}
