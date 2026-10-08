import SwiftUI

struct SharedDetailEditSheet: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(NSLocalizedString("shared_detail_sheet_title", comment: ""))
                    .font(.headline)
                Spacer()
                Button(action: {
                    viewModel.cancelSharedDetailEdit()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .buttonStyle(.borderless)
            }

            if let entry = viewModel.editingSharedDetailEntry {
                Text(entry.title)
                    .font(.subheadline)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
            }

            TextField(NSLocalizedString("enter_detail", comment: ""), text: $viewModel.sharedDetailDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(!viewModel.canEditSharedDetailForSelection)

            if !viewModel.canEditSharedDetailForSelection {
                Text(NSLocalizedString("shared_detail_unavailable", comment: ""))
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            HStack {
                Button(NSLocalizedString("shared_detail_cancel", comment: "")) {
                    viewModel.cancelSharedDetailEdit()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(NSLocalizedString("shared_detail_save", comment: "")) {
                    _ = viewModel.commitSharedDetailEdit()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.currentTheme.accentColor ?? .accentColor)
                .disabled(!viewModel.canEditSharedDetailForSelection)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}
