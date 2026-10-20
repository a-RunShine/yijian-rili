import SwiftUI

@MainActor
struct SettingsOverlay: View {
    @ObservedObject var viewModel: ReviewViewModel
    let palette: ThemePalette
    let canvasMode: CanvasMode
    let availableSize: CGSize
    let toggleCanvas: @MainActor () -> Void
    let openHistory: @MainActor () -> Void
    let dismiss: @MainActor () -> Void

    var body: some View {
        ZStack {
            palette.primary.opacity(0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelWidth: CGFloat {
        min(440, max(0, availableSize.width - 32))
    }

    private var panelHeight: CGFloat {
        max(0, availableSize.height - 32)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    canvasRow
                    themeSection
                    WindowSettingsSection(viewModel: viewModel, forceExpanded: true)
                    CalendarPickerSection(viewModel: viewModel, forceExpanded: true)
                    IntervalSettingsSection(viewModel: viewModel, forceExpanded: true)
                    linkRow(
                        titleKey: "history_title",
                        helpKey: "history_button",
                        action: openHistory
                    )
                    linkRow(
                        titleKey: "weekly_review_button",
                        helpKey: "weekly_review_button",
                        action: { viewModel.openWeeklyReview() }
                    )
                    linkRow(
                        titleKey: "settings_help",
                        helpKey: "help_button_tooltip",
                        action: { viewModel.openHelpGuide() }
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(palette.separator, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("settings_segment_title", comment: ""))
                .font(.headline)
                .foregroundStyle(palette.primary)
            Spacer(minLength: 8)
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("close", comment: ""))
        .accessibilityLabel(NSLocalizedString("close", comment: ""))
    }

    private var canvasRow: some View {
        let help = NSLocalizedString(
            canvasMode == .wide ? "canvas_toggle_to_compact" : "canvas_toggle_to_wide",
            comment: ""
        )
        return Button(action: toggleCanvas) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("canvas_toggle", comment: ""))
                    .foregroundStyle(palette.primary)
                Spacer(minLength: 8)
                Text(NSLocalizedString("canvas_shortcut", comment: ""))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(palette.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("settings_theme_title", comment: ""))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    themeButton(theme)
                }
            }
        }
    }

    private func themeButton(_ theme: Theme) -> some View {
        let selected = viewModel.currentTheme == theme
        return Button {
            viewModel.setTheme(theme)
        } label: {
            Text(theme.displayName)
                .font(.callout)
                .foregroundStyle(selected ? palette.onAccent : palette.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    selected ? palette.accent : palette.chip,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func linkRow(
        titleKey: String,
        helpKey: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        let title = NSLocalizedString(titleKey, comment: "")
        let help = NSLocalizedString(helpKey, comment: "")
        return Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(palette.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(palette.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
    }
}
