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
                HStack(spacing: 4) {
                    Text(entry.baseDate.formattedChinese())
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Text(scheduleTypeLabel(entry.type))
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
            } else if let event = viewModel.browseSharedDetailUnavailableEvent {
                Text(event.title.isEmpty ? NSLocalizedString("untitled", comment: "") : event.title)
                    .font(.subheadline)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                HStack(spacing: 4) {
                    Text(event.isAllDay ? NSLocalizedString("all_day", comment: "") : event.start.formattedTime())
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    Text((event.calendarTitle?.isEmpty == false)
                         ? (event.calendarTitle ?? "")
                         : NSLocalizedString("calendar_default_label", comment: ""))
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
            }

            // macOS TextField(axis: .vertical) + roundedBorder ignores minHeight visually;
            // TextEditor matches WeeklyReviewView and keeps a real multi-line editing plane.
            ZStack(alignment: .topLeading) {
                if viewModel.sharedDetailDraft.isEmpty {
                    Text(NSLocalizedString("enter_detail", comment: ""))
                        .foregroundColor((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.sharedDetailDraft)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160, maxHeight: 280, alignment: .topLeading)
                    .disabled(!viewModel.canEditSharedDetailForSelection || viewModel.sharedDetailEditOutcomeVisible)
            }
            .padding(6)
            .background(viewModel.currentTheme.cardBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)

            if !viewModel.canEditSharedDetailForSelection {
                Text(NSLocalizedString("shared_detail_unavailable", comment: ""))
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let message = viewModel.resultMessage, let type = viewModel.resultType,
               viewModel.sharedDetailEditOutcomeVisible {
                resultBanner(message: message, type: type)
            }

            HStack {
                Button(NSLocalizedString("shared_detail_cancel", comment: "")) {
                    viewModel.cancelSharedDetailEdit()
                }
                .buttonStyle(.bordered)

                Spacer()

                if viewModel.sharedDetailEditOutcomeVisible {
                    Button(NSLocalizedString("shared_detail_done", comment: "")) {
                        viewModel.dismissSharedDetailEditAfterOutcome()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.currentTheme.accentColor ?? .accentColor)
                } else {
                    Button(NSLocalizedString("shared_detail_save", comment: "")) {
                        _ = viewModel.commitSharedDetailEdit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.currentTheme.accentColor ?? .accentColor)
                    .disabled(!viewModel.canEditSharedDetailForSelection)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.easeInOut(duration: 0.25), value: viewModel.sharedDetailEditOutcomeVisible)
    }

    private func scheduleTypeLabel(_ type: HistoryEntry.ScheduleType) -> String {
        switch type {
        case .review: return NSLocalizedString("schedule_mode_review", comment: "")
        case .single: return NSLocalizedString("schedule_mode_single", comment: "")
        }
    }

    private func resultBanner(message: String, type: ReviewViewModel.ResultType) -> some View {
        let (icon, color, bg): (String, Color, Color) = {
            switch type {
            case .success: return ("checkmark.circle.fill", .green, Color.green.opacity(0.1))
            case .warning: return ("exclamationmark.triangle.fill", .orange, Color.orange.opacity(0.1))
            case .error: return ("xmark.circle.fill", .red, Color.red.opacity(0.1))
            }
        }()
        return HStack(spacing: 6) {
            Image(systemName: icon)
            Text(message)
                .font(.callout)
        }
        .foregroundColor(color)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .cornerRadius(8)
    }
}
