import SwiftUI

struct TodayEventsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var isExpanded = false

    private let collapsedLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(NSLocalizedString("today_events", comment: ""), systemImage: "sun.max")
                    .font(.headline)
                Spacer()
                if !viewModel.todayEvents.isEmpty {
                    Text("\(viewModel.todayEvents.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(viewModel.currentTheme.accentColor ?? Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            if viewModel.todayEvents.isEmpty {
                Text(NSLocalizedString("today_no_events", comment: ""))
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            } else {
                let displayCount = isExpanded ? viewModel.todayEvents.count : min(viewModel.todayEvents.count, collapsedLimit)
                ForEach(Array(viewModel.todayEvents.prefix(displayCount).enumerated()), id: \.offset) { index, event in
                    HStack(spacing: 6) {
                        // 日历颜色标识
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
                if viewModel.todayEvents.count > collapsedLimit {
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
                                 : String(format: NSLocalizedString("more_events", comment: ""), "\(viewModel.todayEvents.count - collapsedLimit)"))
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
}
