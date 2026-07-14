import SwiftUI

struct IntervalSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var tempIntervals: [String] = ["3", "7", "30"]
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSavePresetAlert: Bool = false
    @State private var newPresetName: String = ""
    @State private var presetAlertError: String? = nil
    @AppStorage("intervalSettingsExpanded") private var isExpanded: Bool = false

    private var activePreset: IntervalPreset? {
        let current = viewModel.reviewIntervals
        return IntervalPreset.allCases.first { $0.intervals == current }
    }

    private var activeCustomPreset: CustomPreset? {
        let current = viewModel.reviewIntervals
        return viewModel.customPresets.first { $0.intervals == current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠标题栏
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
                    } else if let custom = activeCustomPreset {
                        Text(custom.name)
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
                    // ── 内置预设 ──
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

                    // ── 自定义预设 ──
                    if !viewModel.customPresets.isEmpty || true {
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("custom_presets_label", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

                            ForEach(viewModel.customPresets) { preset in
                                Button(preset.name) {
                                    viewModel.applyCustomPreset(preset)
                                    tempIntervals = viewModel.reviewIntervals.map { String($0) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(activeCustomPreset?.id == preset.id ? (viewModel.currentTheme.accentColor ?? .accentColor) : .secondary)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteCustomPreset(id: preset.id)
                                    } label: {
                                        Label(NSLocalizedString("preset_delete", comment: ""), systemImage: "trash")
                                    }
                                }
                            }

                            Button {
                                newPresetName = ""
                                presetAlertError = nil
                                showSavePresetAlert = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(NSLocalizedString("save_as_preset", comment: ""))
                        }
                    }

                    Divider()

                    // ── 间隔输入列表 ──
                    VStack(spacing: 6) {
                        ForEach(0..<tempIntervals.count, id: \.self) { index in
                            HStack(spacing: 8) {
                                Text(String(format: NSLocalizedString("interval_day_label", comment: ""), "\(index + 1)"))
                                    .font(.caption)
                                    .frame(width: 40, alignment: .leading)

                                TextField("", text: $tempIntervals[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 56)
                                    .multilineTextAlignment(.center)

                                Text("天")
                                    .font(.caption)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

                                Spacer()

                                Button {
                                    tempIntervals.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(tempIntervals.count <= 1)
                                .opacity(tempIntervals.count <= 1 ? 0.3 : 1.0)
                            }
                        }
                    }

                    // ── 添加间隔 ──
                    Button {
                        let lastValue = tempIntervals.last ?? "30"
                        tempIntervals.append(lastValue)
                    } label: {
                        Label(NSLocalizedString("add_interval", comment: ""), systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // ── 错误提示 ──
                    if showError {
                        Text(errorMessage.isEmpty ? NSLocalizedString("interval_invalid", comment: "") : errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // ── 保存 / 恢复默认 ──
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
                            showError = false
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
        .alert(NSLocalizedString("preset_name_title", comment: ""), isPresented: $showSavePresetAlert) {
            TextField(NSLocalizedString("preset_name_placeholder", comment: ""), text: $newPresetName)

            Button(NSLocalizedString("preset_save", comment: "")) {
                savePreset()
            }
            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(NSLocalizedString("preset_cancel", comment: ""), role: .cancel) {
                showSavePresetAlert = false
            }
        } message: {
            if let error = presetAlertError {
                Text(error)
            } else {
                Text(NSLocalizedString("preset_name_message", comment: ""))
            }
        }
    }

    private func saveIntervals() {
        // 检查是否为空
        guard !tempIntervals.isEmpty else {
            errorMessage = NSLocalizedString("interval_min_error", comment: "")
            showError = true
            return
        }

        let intervals = tempIntervals.compactMap { Int($0) }

        guard intervals.count == tempIntervals.count, viewModel.validateIntervals(intervals) else {
            errorMessage = NSLocalizedString("interval_invalid", comment: "")
            showError = true
            return
        }

        showError = false
        errorMessage = ""
        viewModel.reviewIntervals = intervals
        viewModel.updateReviewDates()
    }

    private func savePreset() {
        let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            presetAlertError = NSLocalizedString("preset_name_empty", comment: "")
            return
        }
        if viewModel.hasDuplicatePresetName(trimmed) {
            presetAlertError = NSLocalizedString("preset_name_duplicate", comment: "")
            return
        }
        viewModel.saveCustomPreset(name: trimmed)
        showSavePresetAlert = false
    }
}
