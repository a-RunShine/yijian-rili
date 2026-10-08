import SwiftUI

struct DetailInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("detail_label", comment: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            TextField(NSLocalizedString("enter_detail", comment: ""), text: $viewModel.detail, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}
