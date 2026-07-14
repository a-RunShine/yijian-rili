import SwiftUI

struct IntervalSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var tempIntervals: [String] = ["3", "7", "30"]
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSavePresetAlert: Bool = false
    @State private var newPresetName: String = ""
    @State private var presetAlertError: String? = nil
    /// 记住用户上次手动保存的间隔，用于「恢复已保存」（持久化为 JSON 字符串）
    @AppStorage("savedIntervalsSnapshot") private var savedSnapshotJSON: String = ""
    @State private var showDeletePresetConfirm: Bool = false
    @State private var presetToDelete: CustomPreset? = nil
    @AppStorage("intervalSettingsExpanded") private var isExpanded: Bool = false

    /// 最大间隔数量限制
    private let maxIntervalCount = 10

    /// 从持久化存储读取快照
    private var savedSnapshot: [Int] {
        guard let data = savedSnapshotJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return arr
    }

    /// 将快照写入持久化存储
    private func saveSnapshot(_ intervals: [Int]) {
        if let data = try? JSONEncoder().encode(intervals),
           let str = String(data: data, encoding: .utf8) {
            savedSnapshotJSON = str
        }
    }

    /// 当前是否匹配某个自定义预设（优先于内置预设检查）
    private var activeCustomPreset: CustomPreset? {
        let current = viewModel.reviewIntervals
        return viewModel.customPresets.first { $0.intervals == current }
    }

    /// 当前是否匹配某个内置预设（仅在无自定义预设匹配时生效）
    private var activePreset: IntervalPreset? {
        // 如果匹配自定义预设，则不显示内置预设高亮
        if activeCustomPreset != nil { return nil }
        let current = viewModel.reviewIntervals
        return IntervalPreset.allCases.first { $0.intervals == current }
    }

    /// 是否有可恢复的「已保存」快照（与当前值不同）
    private var canRestoreSaved: Bool {
        !savedSnapshot.isEmpty && savedSnapshot != viewModel.reviewIntervals
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
                    if let custom = activeCustomPreset {
                        Text(custom.name)
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                    } else if let preset = activePreset {
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
                    // ── 内置预设 + 恢复已保存 ──
                    HStack(spacing: 6) {
                        ForEach(IntervalPreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                viewModel.applyPreset(preset)
                                let mapped = viewModel.reviewIntervals.map { String($0) }
                                tempIntervals = mapped
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(activePreset == preset ? (viewModel.currentTheme.accentColor ?? .accentColor) : .secondary)
                        }

                        // 「恢复已保存」按钮：恢复到用户上次手动保存的间隔
                        if canRestoreSaved {
                            Button(NSLocalizedString("restore_saved", comment: "")) {
                                viewModel.reviewIntervals = savedSnapshot
                                tempIntervals = savedSnapshot.map { String($0) }
                                viewModel.updateReviewDates()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(viewModel.currentTheme.accentColor ?? .accentColor)
                        }
                    }

                    // ── 自定义预设 ──
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("custom_presets_label", comment: ""))
                            .font(.caption)
                            .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

                        if viewModel.customPresets.isEmpty {
                            Text(NSLocalizedString("custom_presets_empty", comment: ""))
                                .font(.caption)
                                .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)
                        }

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
                                    presetToDelete = preset
                                    showDeletePresetConfirm = true
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

                                Text(NSLocalizedString("interval_unit_day", comment: ""))
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
                    .disabled(tempIntervals.count >= maxIntervalCount)

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
            let current = viewModel.reviewIntervals
            tempIntervals = current.map { String($0) }
            // 从 @AppStorage 读取快照；首次使用时用当前 reviewIntervals 初始化
            if savedSnapshot.isEmpty {
                saveSnapshot(current)
            }
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
        .alert(NSLocalizedString("preset_delete_confirm_title", comment: ""), isPresented: $showDeletePresetConfirm) {
            Button(NSLocalizedString("preset_delete_confirm_action", comment: ""), role: .destructive) {
                if let preset = presetToDelete {
                    viewModel.deleteCustomPreset(id: preset.id)
                }
                presetToDelete = nil
            }
            Button(NSLocalizedString("preset_delete_cancel", comment: ""), role: .cancel) {
                presetToDelete = nil
            }
        } message: {
            if let preset = presetToDelete {
                Text(String(format: NSLocalizedString("preset_delete_confirm_message", comment: ""), preset.name))
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

        guard tempIntervals.count <= maxIntervalCount else {
            errorMessage = NSLocalizedString("interval_max_error", comment: "")
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
        // 保存后同步 tempIntervals，确保 UI 与存储一致
        tempIntervals = intervals.map { String($0) }
        // 记录快照到持久化存储，供「恢复已保存」使用
        saveSnapshot(intervals)
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
