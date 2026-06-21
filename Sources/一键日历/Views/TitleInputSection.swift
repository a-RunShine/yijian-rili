import SwiftUI

struct TitleInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NSLocalizedString("title", comment: ""), systemImage: "pencil.line")
                .font(.headline)
            TextField(NSLocalizedString("enter_title", comment: ""), text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .onSubmit {
                    Task { await viewModel.createReviewSchedule() }
                }
            
            if viewModel.title.count > 80 {
                HStack {
                    Spacer()
                    Text("\(viewModel.title.count)/100")
                        .font(.caption2)
                        .foregroundColor(viewModel.title.count > 100 ? .red : viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
        .onAppear {
            isFocused = true
        }
    }
}
