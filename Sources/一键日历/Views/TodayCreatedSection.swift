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
                            Text(entry.creationDate.formattedTime())
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

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
        }
    }
}
