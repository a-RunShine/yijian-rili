import SwiftUI

@MainActor
struct HistoryOverlay: View {
    @ObservedObject var viewModel: ReviewViewModel
    let palette: ThemePalette
    let availableSize: CGSize
    @StateObject private var deleteFlow = SearchHitDeleteFlow()

    var body: some View {
        ZStack {
            palette.primary.opacity(0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.showHistory = false
                }
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelWidth: CGFloat {
        min(380, max(0, availableSize.width - 32))
    }

    private var panelHeight: CGFloat {
        min(480, max(0, availableSize.height - 48))
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
            HistorySection(viewModel: viewModel, showsHeader: false, deleteFlow: deleteFlow)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: panelWidth, height: panelHeight)
        .searchHitDeleteAlert(deleteFlow, viewModel: viewModel)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(palette.separator, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString("history_title", comment: ""))
                .font(.headline)
                .foregroundStyle(palette.primary)
            Spacer(minLength: 8)
            if !viewModel.historyEntries.isEmpty {
                Button(NSLocalizedString("clear_history", comment: "")) {
                    viewModel.clearHistory()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            Button(action: { viewModel.showHistory = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(NSLocalizedString("close", comment: ""))
            .accessibilityLabel(NSLocalizedString("close", comment: ""))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
