import SwiftUI

struct ReviewPreviewSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(previewTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.reviewDates.enumerated()), id: \.element) { index, date in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(red: 0.051, green: 0.580, blue: 0.533))
                            .frame(width: 8, height: 8)
                        Text("\(date.formattedChinese()) · \(String(format: NSLocalizedString("review_count", comment: ""), "\(index + 1)"))")
                            .font(.subheadline)
                            .foregroundColor(viewModel.currentTheme.primaryTextColor)
                        Spacer(minLength: 0)
                        Text(daysFromToday(date))
                            .font(.caption2)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                }

                if viewModel.reviewDates.allSatisfy({ Calendar.current.startOfDay(for: $0) < Calendar.current.startOfDay(for: Date()) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                        Text(NSLocalizedString("past_date_warning", comment: ""))
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(viewModel.currentTheme.cardBackgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var previewTitle: String {
        let intervals = viewModel.reviewIntervals.map { "+\($0)" }.joined(separator: " / ")
        return String(format: NSLocalizedString("review_preview_intervals", comment: ""), intervals)
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
