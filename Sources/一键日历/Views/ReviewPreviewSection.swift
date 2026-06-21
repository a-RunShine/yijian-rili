import SwiftUI

struct ReviewPreviewSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NSLocalizedString("review_plan", comment: ""), systemImage: "list.bullet.rectangle")
                .font(.headline)

            ForEach(Array(viewModel.reviewDates.enumerated()), id: \.element) { index, date in
                HStack {
                    Text(String(format: NSLocalizedString("review_count", comment: ""), "\(index + 1)"))
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(date.formattedChinese())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(daysFromToday(date))
                            .font(.caption2)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if viewModel.reviewDates.allSatisfy({ Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: Date()) }) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                    Text(NSLocalizedString("past_date_warning", comment: ""))
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .padding(.top, 2)
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }

    private func daysFromToday(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if diff == 0 {
            return NSLocalizedString("today", comment: "")
        } else if diff > 0 {
            return String(format: NSLocalizedString("days_later", comment: ""), "\(diff)")
        } else {
            return String(format: NSLocalizedString("days_ago", comment: ""), "\(-diff)")
        }
    }
}
