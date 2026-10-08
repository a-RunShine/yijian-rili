import SwiftUI

struct DatePickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("base_date_label", comment: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            DatePicker("", selection: $viewModel.baseDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .onChange(of: viewModel.baseDate) { _, _ in
                    viewModel.updateReviewDates()
                }

            HStack(spacing: 6) {
                Button(NSLocalizedString("today_button", comment: "")) {
                    viewModel.baseDate = Date()
                    viewModel.updateReviewDates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(NSLocalizedString("tomorrow_button", comment: "")) {
                    if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                        viewModel.baseDate = tomorrow
                        viewModel.updateReviewDates()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
