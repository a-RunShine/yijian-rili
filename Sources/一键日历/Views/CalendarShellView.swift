import AppKit
import SwiftUI

@MainActor
struct CalendarShellView: View {
    @EnvironmentObject private var viewModel: ReviewViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsScreenTooNarrowHint = false
    @State private var showsSettings = false
    @State private var switchHovered = false
    @State private var composerOpen = false
    @State private var menuSubmitPending = false
    @State private var contentWidth: CGFloat = CanvasWindowSizing.compactContentSize.width
    @State private var arrowKeyMonitor: Any?

    private let weekdayKeys = [
        "weekday_mon",
        "weekday_tue",
        "weekday_wed",
        "weekday_thu",
        "weekday_fri",
        "weekday_sat",
        "weekday_sun",
    ]
    private let iconRailWidth: CGFloat = 64
    private let editorColumnWidth: CGFloat = 320
    private let controlCornerRadius: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let mode = CanvasBreakpoint.mode(forWidth: proxy.size.width)
            canvas(mode: mode)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(palette.background)
                .overlay {
                    if mode == .compact && composerOpen {
                        composerDrawer(height: proxy.size.height * 0.82)
                            .transition(reduceMotion ? .identity : .move(edge: .bottom))
                    }
                }
                .overlay(alignment: .bottom) {
                    if !composerOpen {
                        ScheduleResultToast()
                            .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .overlay {
                    secondaryOverlay(mode: mode, size: proxy.size)
                }
                .onAppear {
                    contentWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, width in
                    contentWidth = width
                    if CanvasBreakpoint.mode(forWidth: width) == .wide {
                        showsScreenTooNarrowHint = false
                        composerOpen = false
                    }
                }
        }
        .frame(
            minWidth: CanvasWindowSizing.minimumContentSize.width,
            minHeight: CanvasWindowSizing.minimumContentSize.height
        )
        .modifier(CalendarShellPresentations())
        .onReceive(NotificationCenter.default.publisher(for: .toggleCanvas)) { _ in
            toggleCanvas()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newComposer)) { _ in
            beginNewComposer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { _ in
            guard CanvasBreakpoint.mode(forWidth: contentWidth) == .compact else { return }
            setComposerOpen(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .createReviewSchedule)) { _ in
            menuSubmitPending = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissTopPanel)) { _ in
            dismissTopPanel()
        }
        .onExitCommand(perform: canDismissWithEscape ? { dismissTopPanel() } : nil)
        .onAppear(perform: installArrowKeyMonitor)
        .onDisappear(perform: removeArrowKeyMonitor)
        .onChange(of: viewModel.resultMessage) { _, _ in
            finishMenuSubmitIfNeeded()
        }
        .onChange(of: viewModel.title) { oldTitle, newTitle in
            finishMenuSubmitIfTitleCleared(from: oldTitle, to: newTitle)
        }
    }

    private var palette: ThemePalette {
        viewModel.currentTheme.palette
    }

    private func canvas(mode: CanvasMode) -> some View {
        HStack(spacing: 0) {
            if mode == .wide {
                iconRail
                verticalSeparator
            }
            monthWorkspace(mode: mode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if mode == .wide {
                verticalSeparator
                editorColumn
            }
        }
    }

    private var iconRail: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: controlCornerRadius)
                .fill(palette.accent)
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                }
                .accessibilityHidden(true)
            RailIconButton(
                systemName: "sun.max",
                label: NSLocalizedString("today_button", comment: ""),
                palette: palette,
                action: { viewModel.goToToday() }
            )
            RailIconButton(
                systemName: "clock.arrow.circlepath",
                label: NSLocalizedString("history_title", comment: ""),
                palette: palette,
                action: openHistory
            )
            RailIconButton(
                systemName: "gearshape",
                label: NSLocalizedString("segment_settings", comment: ""),
                palette: palette,
                action: openSettings
            )
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(width: iconRailWidth)
        .frame(maxHeight: .infinity)
        .background(palette.chrome)
    }

    private var editorColumn: some View {
        VStack(spacing: 0) {
            ComposerForm(density: .wide, onWillSubmit: noteComposerSubmit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
            BaseDayEventList(
                date: viewModel.baseDate,
                events: events(on: viewModel.baseDate),
                palette: palette
            )
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
            WeeklyProgressCard(
                weekly: viewModel.weeklyReviewViewModel,
                palette: palette,
                open: { viewModel.openWeeklyReview() }
            )
        }
        .frame(width: editorColumnWidth)
        .frame(maxHeight: .infinity)
        .background(palette.card)
    }

    private func composerDrawer(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            palette.primary.opacity(0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissComposer)
            VStack(spacing: 0) {
                ZStack {
                    Capsule()
                        .fill(palette.separator)
                        .frame(width: 36, height: 4)
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: dismissComposer) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help(NSLocalizedString("close", comment: ""))
                        .accessibilityLabel(NSLocalizedString("close", comment: ""))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 1)
                ComposerForm(density: .compact, onWillSubmit: noteComposerSubmit)
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(height, 0))
            .background(palette.card)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 12,
                    style: .continuous
                )
            )
        }
    }

    private func noteComposerSubmit() {
        menuSubmitPending = true
    }

    private func setComposerOpen(_ open: Bool) {
        guard open != composerOpen else { return }
        if reduceMotion {
            composerOpen = open
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                composerOpen = open
            }
        }
    }

    private func dismissComposer() {
        menuSubmitPending = false
        setComposerOpen(false)
    }

    private func finishMenuSubmitIfNeeded() {
        guard menuSubmitPending else { return }
        guard viewModel.resultType != nil else { return }
        let close = shouldCloseComposerAfterSubmit
        menuSubmitPending = false
        guard close, CanvasBreakpoint.mode(forWidth: contentWidth) == .compact else { return }
        setComposerOpen(false)
    }

    private var shouldCloseComposerAfterSubmit: Bool {
        switch viewModel.resultType {
        case .success:
            return true
        case .warning:
            return viewModel.canUndo
        case .error, .none:
            return false
        }
    }

    private func finishMenuSubmitIfTitleCleared(from oldTitle: String, to newTitle: String) {
        guard menuSubmitPending else { return }
        let wasFilled = !oldTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nowEmpty = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard wasFilled, nowEmpty, shouldCloseComposerAfterSubmit else { return }
        menuSubmitPending = false
        guard CanvasBreakpoint.mode(forWidth: contentWidth) == .compact else { return }
        setComposerOpen(false)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    private var horizontalSeparator: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(height: 1)
    }

    private func monthWorkspace(mode: CanvasMode) -> some View {
        let overflow = MonthPreviewWindow.overflow(
            reviewDates: viewModel.reviewDates,
            visibleMonth: viewModel.visibleMonth
        )
        let selectedEvents = events(on: viewModel.baseDate)
        return VStack(spacing: 0) {
            topBar(mode: mode)
            horizontalSeparator
            if showsScreenTooNarrowHint {
                narrowHint
                horizontalSeparator
            }
            if viewModel.authorizationStatus == .denied {
                MonthAccessDenied(palette: palette) {
                    viewModel.openSystemSettings()
                }
            } else {
                weekdayHeader
                monthGrid(mode: mode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if overflow != .none {
                    MonthPreviewOverflowLine(overflow: overflow, palette: palette)
                }
                if mode == .compact {
                    horizontalSeparator
                    MonthDayAgenda(date: viewModel.baseDate, events: selectedEvents, palette: palette)
                    horizontalSeparator
                    MonthCompactFooter(
                        monthCount: displayedMonthEventCount(),
                        baseDate: viewModel.baseDate,
                        dayCount: selectedEvents.count,
                        palette: palette
                    ) {
                        NotificationCenter.default.post(name: .openComposer, object: nil)
                    }
                }
            }
        }
        .background(palette.background)
    }

    private func topBar(mode: CanvasMode) -> some View {
        HStack(spacing: 8) {
            monthStepButton(systemName: "chevron.left", helpKey: "month_previous") {
                viewModel.shiftVisibleMonth(by: -1)
            }
            monthStepButton(systemName: "chevron.right", helpKey: "month_next") {
                viewModel.shiftVisibleMonth(by: 1)
            }
            Text(monthTitle)
                .font(monthFont(mode).weight(.bold).monospacedDigit())
                .foregroundStyle(palette.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: { viewModel.goToToday() }) {
                Text(NSLocalizedString("today_button", comment: ""))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: controlCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: controlCornerRadius)
                            .strokeBorder(palette.separator, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("today_button", comment: ""))
            monthStepButton(systemName: "magnifyingglass", helpKey: "search_button_tooltip") {
                viewModel.showSearch = true
            }
            if mode == .compact {
                monthStepButton(systemName: "clock.arrow.circlepath", helpKey: "history_title") {
                    openHistory()
                }
                monthStepButton(systemName: "gearshape", helpKey: "segment_settings") {
                    openSettings()
                }
            }
            Text(NSLocalizedString("canvas_shortcut", comment: ""))
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.secondary)
            canvasSwitch(mode: mode)
        }
        .padding(.horizontal, 12)
        .frame(height: mode == .wide ? 56 : 50)
        .background(palette.chrome)
    }

    private func monthStepButton(systemName: String, helpKey: String, action: @escaping () -> Void) -> some View {
        let help = NSLocalizedString(helpKey, comment: "")
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.primary)
                .frame(width: 28, height: 28)
                .background(palette.card, in: RoundedRectangle(cornerRadius: controlCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: controlCornerRadius)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func monthFont(_ mode: CanvasMode) -> Font {
        mode == .wide ? .title : .title2
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = WeekCalculator.calendar
        formatter.timeZone = WeekCalculator.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: viewModel.visibleMonth)
    }

    private func canvasSwitch(mode: CanvasMode) -> some View {
        let help = NSLocalizedString(
            mode == .wide ? "canvas_toggle_to_compact" : "canvas_toggle_to_wide",
            comment: ""
        )
        return Button(action: toggleCanvas) {
            Image(systemName: mode == .wide
                ? "arrow.down.right.and.arrow.up.left"
                : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(mode == .wide ? palette.accent : palette.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: controlCornerRadius)
                        .fill(switchBackground(mode: mode))
                )
        }
        .buttonStyle(.plain)
        .onHover { switchHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }

    private func switchBackground(mode: CanvasMode) -> Color {
        if switchHovered {
            return palette.hover
        }
        if mode == .wide {
            return palette.chip
        }
        return .clear
    }

    private var narrowHint: some View {
        Text(NSLocalizedString("canvas_screen_too_narrow", comment: ""))
            .font(.caption)
            .foregroundStyle(palette.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.chrome)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdayKeys, id: \.self) { key in
                Text(NSLocalizedString(key, comment: ""))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func monthGrid(mode: CanvasMode) -> some View {
        let cells = MonthGrid.cells(in: viewModel.visibleMonth, today: Date())
        let ordinals = MonthPreviewWindow.ordinals(for: viewModel.reviewDates)
        return GeometryReader { proxy in
            let spacing: CGFloat = 6
            let gridWidth = max(0, proxy.size.width - 24)
            let gridHeight = max(0, proxy.size.height - 12)
            let rowHeight = max(0, (gridHeight - spacing * 5) / 6)
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(cells, id: \.date) { cell in
                    MonthDayCell(
                        cell: cell,
                        mode: mode,
                        events: events(on: cell.date),
                        previewOrdinal: ordinals[cell.date],
                        rowHeight: rowHeight,
                        palette: palette
                    )
                }
            }
            .frame(width: gridWidth, height: gridHeight, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func events(on day: Date) -> [CalendarEventInfo] {
        viewModel.eventsByDay[Calendar.current.startOfDay(for: day)] ?? []
    }

    private func displayedMonthEventCount() -> Int {
        let cells = MonthGrid.cells(in: viewModel.visibleMonth, today: Date())
        var ids = Set<String>()
        for cell in cells where cell.isInDisplayedMonth {
            for event in events(on: cell.date) {
                ids.insert(event.id)
            }
        }
        return ids.count
    }

    private var canDismissWithEscape: Bool {
        guard !viewModel.modalSheetPresented else { return false }
        return viewModel.showHistory || showsSettings || composerOpen
    }

    private func beginNewComposer() {
        if CanvasBreakpoint.mode(forWidth: contentWidth) == .compact {
            NotificationCenter.default.post(name: .openComposer, object: nil)
        } else {
            NotificationCenter.default.post(name: .focusComposerTitle, object: nil)
        }
    }

    private func dismissTopPanel() {
        guard !viewModel.modalSheetPresented else { return }
        if viewModel.showHistory {
            viewModel.showHistory = false
            return
        }
        if showsSettings {
            showsSettings = false
            return
        }
        if composerOpen {
            dismissComposer()
        }
    }

    private func installArrowKeyMonitor() {
        guard arrowKeyMonitor == nil else { return }
        let relay = ArrowKeyRelay(viewModel: viewModel)
        arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            relay.consume(event)
        }
    }

    private func removeArrowKeyMonitor() {
        if let arrowKeyMonitor {
            NSEvent.removeMonitor(arrowKeyMonitor)
        }
        arrowKeyMonitor = nil
    }

    private func toggleCanvas() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        guard let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let contentRect = window.contentRect(forFrameRect: window.frame)
        let titlebarHeight = window.frame.height - contentRect.height
        let current = CanvasBreakpoint.mode(forWidth: contentRect.width)
        let target: CanvasMode = current == .wide ? .compact : .wide
        let result = CanvasWindowSizing.resize(
            windowFrame: window.frame,
            titlebarHeight: titlebarHeight,
            visibleFrame: visible,
            to: target
        )
        showsScreenTooNarrowHint = result.showsScreenTooNarrowHint
        guard !result.showsScreenTooNarrowHint else {
            showsSettings = false
            return
        }
        window.setFrame(result.windowFrame, display: true, animate: !reduceMotion)
    }

    @ViewBuilder
    private func secondaryOverlay(mode: CanvasMode, size: CGSize) -> some View {
        if viewModel.showHistory {
            HistoryOverlay(viewModel: viewModel, palette: palette, availableSize: size)
        } else if showsSettings {
            SettingsOverlay(
                viewModel: viewModel,
                palette: palette,
                canvasMode: mode,
                availableSize: size,
                toggleCanvas: toggleCanvas,
                openHistory: openHistory,
                dismiss: { showsSettings = false }
            )
        }
    }

    private func openHistory() {
        showsSettings = false
        setComposerOpen(false)
        viewModel.showHistory = true
    }

    private func openSettings() {
        viewModel.showHistory = false
        setComposerOpen(false)
        showsSettings = true
    }
}

@MainActor
private struct CalendarShellPresentations: ViewModifier {
    @EnvironmentObject private var viewModel: ReviewViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showFirstRunGuide) {
                FirstRunGuideView(viewModel: viewModel) {
                    viewModel.dismissFirstRunGuide()
                }
            }
            .sheet(isPresented: $viewModel.showHelpGuide) {
                FirstRunGuideView(viewModel: viewModel) {
                    viewModel.showHelpGuide = false
                }
            }
            .sheet(isPresented: $viewModel.showSearch, onDismiss: {
                viewModel.resetSearch()
            }) {
                SearchSheetView(viewModel: viewModel)
                    .frame(width: 380, height: 460)
            }
            .sheet(isPresented: $viewModel.showWeeklyReview) {
                WeeklyReviewView(viewModel: viewModel.weeklyReviewViewModel)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.isSharedDetailSheetPresented },
                set: { if !$0 { viewModel.cancelSharedDetailEdit() } }
            )) {
                SharedDetailEditSheet(viewModel: viewModel)
                    .frame(width: 380, height: 480)
            }
            .sheet(item: $viewModel.seriesPendingDelete) { hit in
                SeriesDeleteSheet(viewModel: viewModel, hit: hit)
            }
            .onAppear {
                viewModel.scheduleFirstRunGuideIfNeeded()
                viewModel.applyWindowLevel()
            }
            .onChange(of: viewModel.windowFloating) { _, _ in
                viewModel.applyWindowLevel()
            }
            .onChange(of: viewModel.scheduleMode) { _, _ in
                viewModel.updateReviewDates()
            }
    }
}

private final class ArrowKeyRelay: @unchecked Sendable {
    private let viewModel: ReviewViewModel

    init(viewModel: ReviewViewModel) {
        self.viewModel = viewModel
    }

    func consume(_ event: NSEvent) -> NSEvent? {
        guard let step = Self.step(for: event) else { return event }
        let model = viewModel
        let focused = MainActor.assumeIsolated { Self.textInsertionIsFocused }
        guard !focused else { return event }
        MainActor.assumeIsolated {
            model.selectDay(DayNavigation.day(from: model.baseDate, step: step))
        }
        return nil
    }

    private static func step(for event: NSEvent) -> DayNavigationStep? {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return nil }
        switch event.keyCode {
        case 123:
            return .previousDay
        case 124:
            return .nextDay
        case 126:
            return .previousWeek
        case 125:
            return .nextWeek
        default:
            return nil
        }
    }

    @MainActor
    private static var textInsertionIsFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }
}

@MainActor
private struct RailIconButton: View {
    let systemName: String
    let label: String
    let palette: ThemePalette
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundStyle(palette.secondary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered ? palette.hover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

@MainActor
private struct WeeklyProgressCard: View {
    @ObservedObject var weekly: WeeklyReviewViewModel
    let palette: ThemePalette
    let open: @MainActor () -> Void

    var body: some View {
        let reviewed = weekly.reviewedCount
        let total = weekly.totalCount
        let progress = String(
            format: NSLocalizedString("weekly_review_progress", comment: ""),
            "\(reviewed)",
            "\(total)"
        )
        let title = NSLocalizedString("weekly_review_this_week", comment: "")
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                }
                Text(progress)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
                ProgressView(value: total > 0 ? Double(reviewed) / Double(total) : 0)
                    .tint(palette.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(palette.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .help(NSLocalizedString("weekly_review_button", comment: ""))
        .accessibilityLabel("\(title) \(progress)")
    }
}
