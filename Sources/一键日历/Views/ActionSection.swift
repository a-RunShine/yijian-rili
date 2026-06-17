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
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("create_button", comment: ""))
                            .font(.headline)
                        Text("⌘↵")
                            .font(.caption)
                            .opacity(0.7)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(viewModel.currentTheme.accentColor ?? .accentColor)
            .disabled(viewModel.isLoading)
            
            // Recreate Button
            if viewModel.canRecreate {
                Button(action: {
                    viewModel.recreateLastSchedule()
                }) {
                    Label(NSLocalizedString("recreate_button", comment: ""), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
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
                let (icon, color, bg): (String, Color, Color) = {
                    switch type {
                    case .success: return ("checkmark.circle.fill", .green, Color.green.opacity(0.1))
                    case .warning: return ("exclamationmark.triangle.fill", .orange, Color.orange.opacity(0.1))
                    case .error: return ("xmark.circle.fill", .red, Color.red.opacity(0.1))
                    }
                }()
                HStack {
                    Image(systemName: icon)
                    Text(message)
                        .font(.callout)
                }
                .foregroundColor(color)
                .padding()
                .background(bg)
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
