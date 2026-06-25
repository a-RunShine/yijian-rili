import SwiftUI

struct RecreateUndoSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        HStack(spacing: 10) {
            if viewModel.canRecreate {
                Button(action: {
                    viewModel.recreateLastSchedule()
                }) {
                    Label(NSLocalizedString("recreate_button", comment: ""), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85)),
                    removal: .opacity
                ))
            }

            if viewModel.canUndo {
                Button(action: {
                    Task {
                        await viewModel.undoReviewSchedule()
                    }
                }) {
                    Label(NSLocalizedString("undo_button", comment: ""), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.85)),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.canRecreate)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.canUndo)
    }
}
