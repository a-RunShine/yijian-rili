import SwiftUI

struct DatePickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NSLocalizedString("date", comment: ""), systemImage: "calendar")
                .font(.headline)
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
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
