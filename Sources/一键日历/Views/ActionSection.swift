import SwiftUI

struct ActionSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 10) {
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
                        Text(viewModel.scheduleMode == .single
                             ? NSLocalizedString("single_create_button", comment: "")
                             : NSLocalizedString("create_button", comment: ""))
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

            // Recreate + Undo in a row
            HStack(spacing: 10) {
                if viewModel.canRecreate {
                    Button(action: {
                        viewModel.recreateLastSchedule()
                    }) {
                        Label(NSLocalizedString("recreate_button", comment: ""), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
                }
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
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(message)
                        .font(.callout)
                }
                .foregroundColor(color)
                .padding()
                .background(bg)
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        .animation(.easeInOut(duration: 0.25), value: viewModel.resultMessage != nil)
        .animation(.easeInOut(duration: 0.25), value: viewModel.canRecreate)
        .animation(.easeInOut(duration: 0.25), value: viewModel.canUndo)
    }
}
