import AppKit
import SwiftUI

extension Notification.Name {
    static let openComposer = Notification.Name("openComposer")
    static let focusComposerTitle = Notification.Name("focusComposerTitle")
}

@MainActor
struct ComposerForm: View {
    enum Density: Equatable {
        case compact
        case wide
    }

    var density: Density
    var onWillSubmit: () -> Void

    @EnvironmentObject private var viewModel: ReviewViewModel
    @FocusState private var titleFocused: Bool
    @State private var detailExpanded = false
    @State private var titleInvalid = false
    @State private var intervalInvalid = false
    @State private var submitting = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    modeControl
                    baseDateRow
                    titleField
                    detailSection
                    presetSection
                    customIntervalSection
                    previewSection
                    accountSection
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
            submitButton
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            guard density == .compact else { return }
            focusTitleField()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { _ in
            guard density == .compact else { return }
            focusTitleField()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusComposerTitle)) { _ in
            focusTitleField()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createReviewSchedule)) { _ in
            markEmptyTitle()
            trackExternalSubmit()
        }
        .onChange(of: viewModel.title) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                titleInvalid = false
            }
        }
        .onChange(of: viewModel.customIntervalDraft) { _, _ in
            intervalInvalid = false
        }
    }

    private var palette: ThemePalette {
        viewModel.currentTheme.palette
    }

    private var errorColor: Color {
        Color(nsColor: .systemRed)
    }

    private var writeInProgress: Bool {
        submitting || viewModel.isLoading
    }

    private var selection: ComposerPresetSelection {
        ComposerSchedule.presetSelection(
            intervals: viewModel.reviewIntervals,
            savedPresets: viewModel.customPresets
        )
    }

    private var modeControl: some View {
        HStack(spacing: 2) {
            ForEach(ReviewViewModel.ScheduleMode.allCases) { mode in
                let selected = viewModel.scheduleMode == mode
                Button {
                    viewModel.scheduleMode = mode
                } label: {
                    Text(mode.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selected ? palette.onAccent : palette.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(palette.accent)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(2)
        .background(palette.chip, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.separator, lineWidth: 1)
        )
    }

    private var baseDateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("base_date_label")
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.baseDate.formattedChinese())
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                    Text(weekdayText)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 4)
                dayShiftButton(symbol: "chevron.left", labelKey: "composer_previous_day", delta: -1)
                Button {
                    viewModel.selectDay(Date())
                } label: {
                    Text(NSLocalizedString("today_button", comment: ""))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(palette.chip, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(palette.separator, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                dayShiftButton(symbol: "chevron.right", labelKey: "composer_next_day", delta: 1)
            }
        }
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = WeekCalculator.calendar
        formatter.dateFormat = "EEE"
        return formatter.string(from: viewModel.baseDate)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("title")
            TextField(NSLocalizedString("enter_title", comment: ""), text: $viewModel.title)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(palette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(titleInvalid ? errorColor : palette.separator, lineWidth: 1)
                )
                .focused($titleFocused)
        }
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                detailExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(NSLocalizedString("composer_detail", comment: ""))
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: detailExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(palette.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("composer_detail", comment: ""))
            if detailExpanded {
                ZStack(alignment: .topLeading) {
                    if viewModel.detail.isEmpty {
                        Text(NSLocalizedString("enter_detail", comment: ""))
                            .font(.body)
                            .foregroundStyle(palette.secondary.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.detail)
                        .font(.body)
                        .foregroundStyle(palette.primary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 88, maxHeight: 140)
                }
                .padding(6)
                .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(palette.separator, lineWidth: 1)
                )
            }
        }
    }

    private var presetSection: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(IntervalPreset.allCases, id: \.self) { preset in
                presetCard(
                    title: preset.displayName,
                    subtitle: preset.intervals.map(String.init).joined(separator: " · "),
                    selected: isBuiltinSelected(preset)
                ) {
                    viewModel.applyPreset(preset)
                    intervalInvalid = false
                }
            }
            presetCard(
                title: customCardTitle,
                subtitle: customCardSubtitle,
                selected: customSelected,
                action: selectCustomPreset
            )
        }
        .disabled(viewModel.scheduleMode == .single)
        .opacity(viewModel.scheduleMode == .single ? 0.4 : 1)
    }

    private var customIntervalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(
                    NSLocalizedString("composer_interval_placeholder", comment: ""),
                    text: $viewModel.customIntervalDraft
                )
                .textFieldStyle(.plain)
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(intervalInvalid ? errorColor : palette.separator, lineWidth: 1)
                )
                .onSubmit(applyIntervalDraft)
                Button(action: applyIntervalDraft) {
                    Text(NSLocalizedString("composer_apply", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            if intervalInvalid {
                Text(NSLocalizedString("composer_interval_invalid", comment: ""))
                    .font(.caption)
                    .foregroundStyle(errorColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("review_preview_title")
            if density == .wide {
                widePreview
            } else {
                compactPreview
            }
        }
    }

    private var widePreview: some View {
        let outside = ComposerSchedule.daysOutsideMonthGrid(
            month: viewModel.visibleMonth,
            dates: viewModel.reviewDates
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text(countLine("composer_preview_summary", viewModel.reviewDates.count))
                .font(.callout.monospacedDigit())
                .foregroundStyle(palette.primary)
            if outside > 0 {
                Text(countLine("composer_preview_outside", outside))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
            }
        }
    }

    private var compactPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(viewModel.reviewDates.enumerated()), id: \.offset) { index, date in
                HStack(spacing: 8) {
                    Text(date.formattedChinese())
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if viewModel.scheduleMode == .review {
                        Text(String(format: NSLocalizedString("review_count", comment: ""), "\(index + 1)"))
                            .font(.caption)
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(palette.separator, lineWidth: 1)
        )
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("composer_account")
            CalendarPickerSection(
                viewModel: viewModel,
                forceExpanded: true,
                showsTitle: false,
                showsStatusHint: false
            )
            if viewModel.isSelectedCalendarLocal {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(NSLocalizedString("composer_local_hint", comment: ""))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(Color.orange)
            }
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if writeInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.onAccent)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 8) {
                        Text(submitTitle)
                        Text(NSLocalizedString("composer_shortcut", comment: ""))
                            .font(.caption.monospacedDigit())
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.onAccent)
            .padding(.vertical, 8)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(writeInProgress)
        .accessibilityLabel(submitTitle)
        .help(NSLocalizedString("composer_shortcut", comment: ""))
    }

    private var submitTitle: String {
        countLine("composer_submit", viewModel.reviewDates.count)
    }

    private var customSelected: Bool {
        if case .custom = selection {
            return true
        }
        return false
    }

    private var customCardTitle: String {
        if case .custom(let name?) = selection {
            return name
        }
        return NSLocalizedString("composer_preset_custom", comment: "")
    }

    private var customCardSubtitle: String {
        guard customSelected else { return " " }
        let text = viewModel.reviewIntervals.map(String.init).joined(separator: " · ")
        return text.isEmpty ? " " : text
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(NSLocalizedString(key, comment: ""))
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondary)
    }

    private func dayShiftButton(symbol: String, labelKey: String, delta: Int) -> some View {
        let label = NSLocalizedString(labelKey, comment: "")
        return Button {
            shiftBaseDate(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.primary)
                .frame(width: 28, height: 28)
                .background(palette.chip, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(palette.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func presetCard(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                    .opacity(subtitle.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
            }
            .foregroundStyle(selected ? palette.onAccent : palette.primary)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(selected ? palette.accent : palette.chip, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? palette.accent : palette.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func isBuiltinSelected(_ preset: IntervalPreset) -> Bool {
        switch (selection, preset) {
        case (.classic, .classic), (.exam, .exam), (.daily, .daily):
            return true
        default:
            return false
        }
    }

    private func selectCustomPreset() {
        let preset = viewModel.customPresets.first { $0.intervals == viewModel.reviewIntervals }
            ?? viewModel.customPresets.last
        guard let preset else { return }
        viewModel.applyCustomPreset(preset)
        intervalInvalid = false
    }

    private func shiftBaseDate(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: viewModel.baseDate) else { return }
        viewModel.selectDay(date)
    }

    private func applyIntervalDraft() {
        let separators = CharacterSet(charactersIn: ",，、").union(.whitespacesAndNewlines)
        let tokens = viewModel.customIntervalDraft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        switch viewModel.commitIntervalDraft(tokens) {
        case .success:
            intervalInvalid = false
        case .failure:
            intervalInvalid = true
        }
    }

    private func submit() {
        guard !writeInProgress else { return }
        markEmptyTitle()
        onWillSubmit()
        submitting = true
        Task { @MainActor in
            await viewModel.createReviewSchedule()
            submitting = false
        }
    }

    private func trackExternalSubmit() {
        submitting = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            if !viewModel.session.isLoading {
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
            while viewModel.session.isLoading {
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
            submitting = false
        }
    }

    private func markEmptyTitle() {
        guard viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        titleInvalid = true
        focusTitleField()
    }

    private func focusTitleField() {
        Task { @MainActor in
            titleFocused = true
        }
    }

    private func countLine(_ key: String, _ count: Int) -> String {
        String(format: NSLocalizedString(key, comment: ""), "\(count)")
    }
}
