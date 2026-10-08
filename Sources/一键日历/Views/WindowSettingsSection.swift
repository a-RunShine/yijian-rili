import SwiftUI

struct WindowSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    var forceExpanded: Bool = false
    @AppStorage("windowSettingsExpanded") private var isExpanded: Bool = false

    private var expanded: Bool { forceExpanded || isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if forceExpanded {
                Text(NSLocalizedString("window_section_title", comment: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .padding(.bottom, 8)

                HStack {
                    Text(NSLocalizedString("window_always_on_top", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(viewModel.currentTheme.primaryTextColor)
                    Spacer()
                    Toggle("", isOn: $viewModel.windowFloating)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding()
                .background(viewModel.currentTheme.cardBackgroundColor)
                .cornerRadius(10)
            } else {
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

                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("window_always_on_top", comment: ""))
                                .font(.subheadline)
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
        }
        .padding(forceExpanded ? 0 : 16)
        .background(forceExpanded ? Color.clear : viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
    }
}
