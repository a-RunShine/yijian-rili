import SwiftUI

struct DatePickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("date", comment: ""))
                .font(.headline)
            DatePicker("", selection: $viewModel.baseDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .onChange(of: viewModel.baseDate) { _, _ in
                    viewModel.updateReviewDates()
                }
        }
    }
}
