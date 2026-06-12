import SwiftUI

struct ActionSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Create Button
            Button(action: {
                Task {
                    await viewModel.createReviewSchedule()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text(NSLocalizedString("create_button", comment: ""))
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            
            // Undo Button
            if viewModel.canUndo {
                Button(action: {
                    Task {
                        await viewModel.undoReviewSchedule()
                    }
                }) {
                    Text(NSLocalizedString("undo_button", comment: ""))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Result Message
            if let message = viewModel.resultMessage, let type = viewModel.resultType {
                HStack {
                    Image(systemName: type == .success ? "checkmark.circle.fill" : type == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    Text(message)
                        .font(.callout)
                }
                .foregroundColor(type == .success ? .green : type == .warning ? .orange : .red)
                .padding()
                .background(type == .success ? Color.green.opacity(0.1) : type == .warning ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Permission denied button
            if viewModel.authorizationStatus == .denied {
                Button(NSLocalizedString("open_settings", comment: "")) {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
