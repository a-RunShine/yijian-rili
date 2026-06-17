import SwiftUI

struct TitleInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NSLocalizedString("title", comment: ""), systemImage: "pencil.line")
                .font(.headline)
            TextField(NSLocalizedString("enter_title", comment: ""), text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
