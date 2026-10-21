import SwiftUI

@MainActor
final class SearchHitDeleteFlow: ObservableObject {
    @Published private(set) var hitPendingDelete: SearchHit?

    func request(_ hit: SearchHit, in viewModel: ReviewViewModel) {
        guard !hit.needsSelectiveDelete else {
            viewModel.beginSeriesDelete(hit)
            return
        }
        hitPendingDelete = hit
    }

    func cancel() {
        hitPendingDelete = nil
    }

    func confirm(in viewModel: ReviewViewModel) {
        guard let hit = hitPendingDelete else { return }
        hitPendingDelete = nil
        let deleted = viewModel.deleteSearchHit(hit)
        guard deleted, viewModel.selectedSearchHit?.id == hit.id else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            viewModel.clearSearchSelection()
        }
    }
}

extension View {
    func searchHitDeleteAlert(
        _ flow: SearchHitDeleteFlow,
        viewModel: ReviewViewModel
    ) -> some View {
        modifier(SearchHitDeleteAlert(flow: flow, viewModel: viewModel))
    }
}

@MainActor
private struct SearchHitDeleteAlert: ViewModifier {
    @ObservedObject var flow: SearchHitDeleteFlow
    let viewModel: ReviewViewModel

    func body(content: Content) -> some View {
        content.alert(
            NSLocalizedString("search_delete_confirm_title", comment: ""),
            isPresented: Binding(
                get: { flow.hitPendingDelete != nil },
                set: { if !$0 { flow.cancel() } }
            ),
            presenting: flow.hitPendingDelete
        ) { _ in
            Button(NSLocalizedString("search_delete_cancel", comment: ""), role: .cancel) {
                flow.cancel()
            }
            Button(NSLocalizedString("search_delete_confirm_action", comment: ""), role: .destructive) {
                flow.confirm(in: viewModel)
            }
        } message: { hit in
            Text(String(
                format: NSLocalizedString("search_delete_confirm_message", comment: ""),
                hit.title.isEmpty ? NSLocalizedString("untitled", comment: "") : hit.title
            ))
        }
    }
}
