import SwiftUI

@MainActor
final class SearchHitDeleteFlow: ObservableObject {
    @Published private(set) var hitPendingDelete: SearchHit?
    private var historyEntryPendingDelete: HistoryEntry?

    func request(_ hit: SearchHit, in viewModel: ReviewViewModel) {
        guard !hit.asksForDeleteScope else {
            viewModel.beginSeriesDelete(hit)
            return
        }
        hitPendingDelete = hit
    }

    func requestDeletingHistory(_ entry: HistoryEntry, in viewModel: ReviewViewModel) {
        historyEntryPendingDelete = entry
        let hit = viewModel.hit(forHistoryEntry: entry)
        guard !hit.asksForDeleteScope else {
            viewModel.beginSeriesDelete(hit)
            return
        }
        hitPendingDelete = hit
    }

    func cancel() {
        hitPendingDelete = nil
        historyEntryPendingDelete = nil
    }

    func confirm(in viewModel: ReviewViewModel) {
        guard let hit = hitPendingDelete else { return }
        hitPendingDelete = nil
        if let entry = historyEntryPendingDelete {
            historyEntryPendingDelete = nil
            viewModel.deleteHistoryEntry(entry, members: hit.members.map(\.id))
            return
        }
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
