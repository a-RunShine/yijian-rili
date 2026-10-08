import SwiftUI
import AppKit

struct DatePickerSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var showCalendar = false

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("base_date_label", comment: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

            Button {
                showCalendar.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.baseDate.formattedChinese())
                        .font(.body)
                        .foregroundColor(viewModel.currentTheme.primaryTextColor ?? .primary)
                    Spacer(minLength: 0)
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .background(fieldShape.fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    fieldShape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .clipShape(fieldShape)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                DatePicker(
                    "",
                    selection: $viewModel.baseDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(12)
                .onChange(of: viewModel.baseDate) { _, _ in
                    viewModel.updateReviewDates()
                }
            }

            HStack(spacing: 6) {
                Button(NSLocalizedString("today_button", comment: "")) {
                    viewModel.baseDate = Date()
                    viewModel.updateReviewDates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(NSLocalizedString("tomorrow_button", comment: "")) {
                    if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                        viewModel.baseDate = tomorrow
                        viewModel.updateReviewDates()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
