import SwiftUI

struct TodayCreatedSection: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("today_created_title", comment: ""))
                .font(.headline)
                .foregroundColor(viewModel.currentTheme.primaryTextColor)

            if viewModel.todayCreatedEntries.isEmpty {
                Text(NSLocalizedString("today_created_empty", comment: ""))
                    .font(.caption)
                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewModel.currentTheme.cardBackgroundColor)
                    .cornerRadius(10)
            } else {
                ForEach(viewModel.todayCreatedEntries) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.051, green: 0.580, blue: 0.533))
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.currentTheme.primaryTextColor)
                                .lineLimit(1)
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
                                Text("·")
                                    .font(.caption)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                                Text(entry.creationDate.formattedTime())
                                    .font(.caption)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                            }

                            if entry.createdEventIdentifiers.isEmpty {
                                Text(NSLocalizedString("today_created_edit_unavailable", comment: ""))
                                    .font(.caption2)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                            } else {
                                Button(NSLocalizedString("today_created_edit_detail", comment: "")) {
                                    viewModel.beginSharedDetailEdit(for: entry)
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                .foregroundColor(viewModel.currentTheme.accentColor ?? .accentColor)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(viewModel.currentTheme.cardBackgroundColor)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke((viewModel.currentTheme.secondaryTextColor ?? .secondary).opacity(0.2), lineWidth: 1)
                    )
                }
            }

            if viewModel.sharedDetailResultOnToday,
               let message = viewModel.resultMessage,
               let type = viewModel.resultType {
                resultBanner(message: message, type: type)
            }
        }
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .cornerRadius(8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.25), value: viewModel.resultMessage != nil)
    }
}
