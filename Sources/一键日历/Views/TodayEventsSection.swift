import SwiftUI

struct TodayEventsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("today_events", comment: ""))
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
                ForEach(Array(viewModel.todayEvents.prefix(5).enumerated()), id: \.offset) { _, event in
                    HStack {
                        if event.isAllDay {
                            Text(NSLocalizedString("all_day", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 50, alignment: .leading)
                        } else {
                            Text(event.startDate.formattedTime())
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                .frame(width: 50, alignment: .leading)
                        }
                        Text(event.title ?? NSLocalizedString("untitled", comment: ""))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                if viewModel.todayEvents.count > 5 {
                    Text(String(format: NSLocalizedString("more_events", comment: ""), "\(viewModel.todayEvents.count - 5)"))
                        .font(.caption2)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(8)
    }
}
