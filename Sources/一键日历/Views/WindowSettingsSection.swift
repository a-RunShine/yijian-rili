import SwiftUI

struct WindowSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @AppStorage("windowSettingsExpanded") private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(NSLocalizedString("window_settings_title", comment: ""), systemImage: "macwindow")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.windowFloating
                         ? NSLocalizedString("window_floating_on", comment: "")
                         : NSLocalizedString("window_floating_off", comment: ""))
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Toggle("", isOn: $viewModel.windowFloating)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Text(NSLocalizedString("window_floating_hint", comment: ""))
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
