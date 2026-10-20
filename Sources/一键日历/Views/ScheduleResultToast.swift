import AppKit
import SwiftUI

@MainActor
struct ScheduleResultToast: View {
    @EnvironmentObject private var viewModel: ReviewViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let message = viewModel.resultMessage, let type = viewModel.resultType {
            card(message: message, type: type)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var palette: ThemePalette {
        viewModel.currentTheme.palette
    }

    private func card(message: String, type: ReviewViewModel.ResultType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbolName(type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tone(type))
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(palette.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if offersUndo(type) {
                    undoButton
                }
            }
            if offersSystemSettings(message: message, type: type) {
                settingsButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 480)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(palette.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var undoButton: some View {
        Button {
            Task { await viewModel.undoReviewSchedule() }
        } label: {
            Text(NSLocalizedString("undo_button", comment: ""))
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(palette.chip, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .accessibilityLabel(NSLocalizedString("undo_button", comment: ""))
    }

    private var settingsButton: some View {
        Button {
            viewModel.openSystemSettings()
        } label: {
            Text(NSLocalizedString("open_settings", comment: ""))
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("open_settings", comment: ""))
    }

    private func offersUndo(_ type: ReviewViewModel.ResultType) -> Bool {
        guard viewModel.canUndo else { return false }
        switch type {
        case .success, .warning:
            return true
        case .error:
            return false
        }
    }

    private func offersSystemSettings(message: String, type: ReviewViewModel.ResultType) -> Bool {
        guard type == .error else { return false }
        return message == NSLocalizedString("permission_denied", comment: "")
            || message == NSLocalizedString("permission_required", comment: "")
    }

    private func symbolName(_ type: ReviewViewModel.ResultType) -> String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private func tone(_ type: ReviewViewModel.ResultType) -> Color {
        switch type {
        case .success:
            return palette.success
        case .warning:
            return Color(nsColor: .systemOrange)
        case .error:
            return Color(nsColor: .systemRed)
        }
    }
}
