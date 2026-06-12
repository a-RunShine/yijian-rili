import SwiftUI

struct ReviewPreviewSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("review_plan", comment: ""))
                .font(.headline)
            
            ForEach(Array(viewModel.reviewDates.enumerated()), id: \.element) { index, date in
                HStack {
                    Text(String(format: NSLocalizedString("review_count", comment: ""), "\(index + 1)"))
                    Spacer()
                    Text(date.formattedChinese())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(8)
    }
}
