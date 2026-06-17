import SwiftUI

struct IntervalSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var tempIntervals: [String] = ["3", "7", "30"]
    @State private var showError: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("interval_settings_title", comment: ""))
                .font(.headline)
            
            // 间隔预设
            HStack(spacing: 8) {
                ForEach(IntervalPreset.allCases, id: \.self) { preset in
                    Button(preset.displayName) {
                        viewModel.applyPreset(preset)
                        tempIntervals = viewModel.reviewIntervals.map { String($0) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            HStack(spacing: 16) {
                ForEach(0..<tempIntervals.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text(String(format: NSLocalizedString("interval_day_label", comment: ""), "\(index + 1)"))
                            .font(.caption)
                        TextField("", text: $tempIntervals[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            if showError {
                Text(NSLocalizedString("interval_invalid", comment: ""))
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
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
        .padding()
        .background(viewModel.currentTheme.cardBackgroundColor)
        .cornerRadius(8)
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
