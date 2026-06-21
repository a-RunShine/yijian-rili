import SwiftUI

struct IntervalSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var tempIntervals: [String] = ["3", "7", "30"]
    @State private var showError: Bool = false
    @State private var isExpanded: Bool = false

    private var activePreset: IntervalPreset? {
        let current = viewModel.reviewIntervals
        return IntervalPreset.allCases.first { $0.intervals == current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(NSLocalizedString("interval_settings_title", comment: ""), systemImage: "slider.horizontal.3")
                        .font(.headline)
                    Spacer()
                    if let preset = activePreset {
                        Text(preset.displayName)
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // 间隔预设
                    HStack(spacing: 6) {
                        ForEach(IntervalPreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                viewModel.applyPreset(preset)
                                tempIntervals = viewModel.reviewIntervals.map { String($0) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(activePreset == preset ? (viewModel.currentTheme.accentColor ?? .accentColor) : .secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        ForEach(0..<tempIntervals.count, id: \.self) { index in
                            VStack(spacing: 4) {
                                Text(String(format: NSLocalizedString("interval_day_label", comment: ""), "\(index + 1)"))
                                    .font(.caption)
                                TextField("", text: $tempIntervals[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 56)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                    if showError {
                        Text(NSLocalizedString("interval_invalid", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    HStack(spacing: 10) {
                        Button(NSLocalizedString("save_intervals", comment: "")) {
                            saveIntervals()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(viewModel.currentTheme.accentColor ?? .accentColor)

                        Button(NSLocalizedString("reset_intervals", comment: "")) {
                            viewModel.resetIntervalsToDefault()
                            tempIntervals = viewModel.reviewIntervals.map { String($0) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(10)
        .onAppear {
            tempIntervals = viewModel.reviewIntervals.map { String($0) }
        }
    }

    private func saveIntervals() {
        let intervals = tempIntervals.compactMap { Int($0) }

        guard !intervals.isEmpty, intervals.count == tempIntervals.count, viewModel.validateIntervals(intervals) else {
            showError = true
            return
        }

        showError = false
        viewModel.reviewIntervals = intervals
        viewModel.updateReviewDates()
    }
}
