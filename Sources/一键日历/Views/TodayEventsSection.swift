import SwiftUI

struct TodayEventsSection: View {
    @ObservedObject var viewModel: ReviewViewModel

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
                ForEach(Array(viewModel.todayEvents.prefix(5).enumerated()), id: \.offset) { index, event in
                    HStack {
                        if event.isAllDay {
                            Text(NSLocalizedString("all_day", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 46, alignment: .leading)
                        } else {
                            Text(event.startDate.formattedTime())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 46, alignment: .leading)
                        }
                        Text(event.title ?? NSLocalizedString("untitled", comment: ""))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 3)

                    if index < min(viewModel.todayEvents.count, 5) - 1 {
                        Divider()
                    }
                }
                if viewModel.todayEvents.count > 5 {
                    Text(String(format: NSLocalizedString("more_events", comment: ""), "\(viewModel.todayEvents.count - 5)"))
                        .font(.caption2)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
