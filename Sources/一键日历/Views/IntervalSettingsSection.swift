import SwiftUI

struct IntervalEntry: Identifiable {
    let id = UUID()
    var value: String
}

struct IntervalSettingsSection: View {
    @ObservedObject var viewModel: ReviewViewModel
    @State private var tempIntervals: [IntervalEntry] = [IntervalEntry(value: "3"), IntervalEntry(value: "7"), IntervalEntry(value: "30")]
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSavePresetAlert: Bool = false
    @State private var newPresetName: String = ""
    @State private var presetAlertError: String? = nil
    @AppStorage("savedIntervalsSnapshot") private var savedSnapshotJSON: String = ""
    @State private var showDeletePresetConfirm: Bool = false
    @State private var presetToDelete: CustomPreset? = nil
    @AppStorage("intervalSettingsExpanded") private var isExpanded: Bool = false
    @State private var hasInitialized: Bool = false

    private let maxIntervalCount = 10

    private var savedSnapshot: [Int] {
        guard let data = savedSnapshotJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return arr
    }

    private func saveSnapshot(_ intervals: [Int]) {
        if let data = try? JSONEncoder().encode(intervals),
           let str = String(data: data, encoding: .utf8) {
            savedSnapshotJSON = str
        }
    }

    private var activeCustomPreset: CustomPreset? {
        let current = viewModel.reviewIntervals
        return viewModel.customPresets.first { $0.intervals == current }
    }

    private var activePreset: IntervalPreset? {
        if activeCustomPreset != nil { return nil }
        let current = viewModel.reviewIntervals
        return IntervalPreset.allCases.first { $0.intervals == current }
    }

    private var canRestoreSaved: Bool {
        !savedSnapshot.isEmpty && savedSnapshot != viewModel.reviewIntervals
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
                    HStack(spacing: 6) {
                        ForEach(IntervalPreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                viewModel.applyPreset(preset)
                                tempIntervals = viewModel.reviewIntervals.map { IntervalEntry(value: String($0)) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(activePreset == preset ? (viewModel.currentTheme.accentColor ?? .accentColor) : .secondary)
                        }

                        if canRestoreSaved {
                            Button(NSLocalizedString("restore_saved", comment: "")) {
                                viewModel.reviewIntervals = savedSnapshot
                                tempIntervals = savedSnapshot.map { IntervalEntry(value: String($0)) }
                                viewModel.updateReviewDates()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(viewModel.currentTheme.accentColor ?? .accentColor)
                        }
                    }

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
                                tempIntervals = viewModel.reviewIntervals.map { IntervalEntry(value: String($0)) }
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

                    VStack(spacing: 6) {
                        ForEach(Array(tempIntervals.enumerated()), id: \.element.id) { index, entry in
                            let parsed = Int(entry.value.trimmingCharacters(in: .whitespaces))
                            let isInvalid = parsed == nil || parsed! < 1 || parsed! > 365
                            HStack(spacing: 8) {
                                Text(String(format: NSLocalizedString("interval_day_label", comment: ""), "\(index + 1)"))
                                    .font(.caption)
                                    .frame(width: 40, alignment: .leading)

                                TextField("", text: $tempIntervals[index].value)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 56)
                                    .multilineTextAlignment(.center)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 1)
                                    )

                                Text(NSLocalizedString("interval_unit_day", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(viewModel.currentTheme.secondaryTextColor ?? .secondary)

                                Spacer()

                                Button {
                                    tempIntervals.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(tempIntervals.count <= 1)
                                .opacity(tempIntervals.count <= 1 ? 0.3 : 1.0)
                                .accessibilityLabel(String(format: NSLocalizedString("remove_interval_at", comment: ""), "\(index + 1)"))
                            }
                        }
                    }

                    Button {
                        let lastValid = tempIntervals.last(where: { Int($0.value.trimmingCharacters(in: .whitespaces)) != nil })?.value ?? "7"
                        tempIntervals.append(IntervalEntry(value: lastValid))
                    } label: {
                        Label(NSLocalizedString("add_interval", comment: ""), systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(tempIntervals.count >= maxIntervalCount)

                    if showError {
                        Text(errorMessage.isEmpty ? NSLocalizedString("interval_invalid", comment: "") : errorMessage)
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
                            tempIntervals = viewModel.reviewIntervals.map { IntervalEntry(value: String($0)) }
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
            guard !hasInitialized else { return }
            hasInitialized = true
            let current = viewModel.reviewIntervals
            tempIntervals = current.map { IntervalEntry(value: String($0)) }
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

    private func message(for failure: IntervalDraftFailure) -> String {
        switch failure {
        case .empty:
            return NSLocalizedString("interval_min_error", comment: "")
        case .tooMany:
            return NSLocalizedString("interval_max_error", comment: "")
        case .invalidAt(let index):
            return String(format: NSLocalizedString("interval_invalid_at", comment: ""), "\(index)")
        case .notIncreasingAt(let index):
            return String(format: NSLocalizedString("interval_not_increasing_at", comment: ""), "\(index)")
        }
    }

    private func saveIntervals() {
        let draft = tempIntervals.map(\.value)
        switch viewModel.commitIntervalDraft(draft) {
        case .success(let intervals):
            showError = false
            errorMessage = ""
            tempIntervals = intervals.map { IntervalEntry(value: String($0)) }
            saveSnapshot(intervals)
        case .failure(let failure):
            errorMessage = message(for: failure)
            showError = true
        }
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
        let draft = tempIntervals.map(\.value)
        switch viewModel.commitIntervalDraft(draft) {
        case .success(let intervals):
            tempIntervals = intervals.map { IntervalEntry(value: String($0)) }
            viewModel.saveCustomPreset(name: trimmed)
            showSavePresetAlert = false
            presetAlertError = nil
        case .failure:
            presetAlertError = NSLocalizedString("preset_save_invalid_intervals", comment: "")
        }
    }
}
