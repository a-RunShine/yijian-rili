import SwiftUI

struct DetailInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("detail_label", comment: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            ZStack(alignment: .topLeading) {
                if viewModel.detail.isEmpty {
                    Text(NSLocalizedString("enter_detail", comment: ""))
                        .foregroundColor((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.detail)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120, maxHeight: 220, alignment: .topLeading)
            }
            .padding(6)
            .background(viewModel.currentTheme.cardBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.35), lineWidth: 1)
            )
        }
    }
}
