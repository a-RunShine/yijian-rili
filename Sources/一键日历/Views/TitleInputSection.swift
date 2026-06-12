import SwiftUI

struct TitleInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("title", comment: ""))
                .font(.headline)
            TextField(NSLocalizedString("enter_title", comment: ""), text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}
