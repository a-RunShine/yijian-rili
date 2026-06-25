import SwiftUI

struct TitleInputSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            scheduleModePicker

            Label(NSLocalizedString("title", comment: ""), systemImage: "pencil.line")
                .font(.headline)
            TextField(NSLocalizedString("enter_title", comment: ""), text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .onSubmit {
                    Task { await viewModel.createReviewSchedule() }
                }

            if viewModel.title.count > 80 {
                HStack {
                    Spacer()
                    Text("\(viewModel.title.count)/100")
                        .font(.caption2)
                        .foregroundColor(viewModel.title.count > 100 ? .red : viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
        .id("titleInput")
        .onAppear {
            isFocused = true
        }
    }

    /// 自定义 Segmented Picker：选中段的背景色块在两个段之间用 spring 滑动
    private var scheduleModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ReviewViewModel.ScheduleMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        viewModel.scheduleMode = mode
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(
                            viewModel.scheduleMode == mode
                                ? .white
                                : (viewModel.currentTheme.primaryTextColor ?? .primary)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
        .background(
            GeometryReader { geo in
                let modes = ReviewViewModel.ScheduleMode.allCases
                let count = CGFloat(modes.count)
                let segWidth = geo.size.width / count
                let index = CGFloat(modes.firstIndex(of: viewModel.scheduleMode) ?? 0)
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.currentTheme.accentColor ?? .accentColor)
                    .frame(width: segWidth)
                    .offset(x: index * segWidth)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.scheduleMode)
            }
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.currentTheme.cardBackgroundColor)
        )
    }
}
