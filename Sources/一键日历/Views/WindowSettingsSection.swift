import SwiftUI

struct WindowSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(NSLocalizedString("window_settings_title", comment: ""), systemImage: "macwindow")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $viewModel.windowFloating)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text(NSLocalizedString("window_floating_hint", comment: ""))
                .font(.caption)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
