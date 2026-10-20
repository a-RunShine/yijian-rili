import AppKit
import SwiftUI

@MainActor
struct CalendarShellView: View {
    @EnvironmentObject private var viewModel: ReviewViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsScreenTooNarrowHint = false
    @State private var switchHovered = false
    @State private var composerOpen = false
    @State private var menuSubmitPending = false
    @State private var contentWidth: CGFloat = CanvasWindowSizing.compactContentSize.width

    private let weekdayKeys = [
        "weekday_mon",
        "weekday_tue",
        "weekday_wed",
        "weekday_thu",
        "weekday_fri",
        "weekday_sat",
        "weekday_sun",
    ]
    private let railSymbols = ["calendar", "sun.max", "clock.arrow.circlepath", "gearshape"]
    private let iconRailWidth: CGFloat = 64
    private let editorColumnWidth: CGFloat = 320
    private let cellCornerRadius: CGFloat = 8
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
        .onReceive(NotificationCenter.default.publisher(for: .openComposer)) { _ in
            guard CanvasBreakpoint.mode(forWidth: contentWidth) == .compact else { return }
            setComposerOpen(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .createReviewSchedule)) { _ in
            menuSubmitPending = true
        }
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
                    Image(systemName: railSymbols[0])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                }
            ForEach(railSymbols.dropFirst(), id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 34, height: 34)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(width: iconRailWidth)
        .frame(maxHeight: .infinity)
        .background(palette.chrome)
        .accessibilityHidden(true)
    }

    private var editorColumn: some View {
        ComposerForm(density: .wide, onWillSubmit: noteComposerSubmit)
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
        let succeeded = viewModel.resultType == .success
        menuSubmitPending = false
        guard succeeded, CanvasBreakpoint.mode(forWidth: contentWidth) == .compact else { return }
        setComposerOpen(false)
    }

    private func finishMenuSubmitIfTitleCleared(from oldTitle: String, to newTitle: String) {
        guard menuSubmitPending else { return }
        let wasFilled = !oldTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let nowEmpty = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard wasFilled, nowEmpty, viewModel.resultType == .success else { return }
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
        VStack(spacing: 0) {
            topBar(mode: mode)
            horizontalSeparator
            if showsScreenTooNarrowHint {
                narrowHint
                horizontalSeparator
            }
            weekdayHeader
            monthGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.background)
    }

    private func topBar(mode: CanvasMode) -> some View {
        HStack(spacing: 8) {
            Text(monthTitle)
                .font(monthFont(mode).weight(.bold).monospacedDigit())
                .foregroundStyle(palette.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(NSLocalizedString("canvas_shortcut", comment: ""))
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.secondary)
            canvasSwitch(mode: mode)
        }
        .padding(.horizontal, 12)
        .frame(height: mode == .wide ? 56 : 50)
        .background(palette.chrome)
    }

    private func monthFont(_ mode: CanvasMode) -> Font {
        mode == .wide ? .title : .title2
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = WeekCalculator.calendar
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: viewModel.baseDate)
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

    private var monthGrid: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 6
            let gridWidth = max(0, proxy.size.width - 24)
            let gridHeight = max(0, proxy.size.height - 12)
            let rowHeight = max(0, (gridHeight - spacing * 5) / 6)
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(MonthGrid.cells(in: viewModel.baseDate, today: Date()), id: \.date) { cell in
                    Text(dayNumber(cell.date))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(cell.isInDisplayedMonth ? palette.primary : palette.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: cellCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: cellCornerRadius)
                                .strokeBorder(palette.separator, lineWidth: 1)
                        }
                }
            }
            .frame(width: gridWidth, height: gridHeight, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func dayNumber(_ date: Date) -> String {
        String(WeekCalculator.calendar.component(.day, from: date))
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
        guard !result.showsScreenTooNarrowHint else { return }
        window.setFrame(result.windowFrame, display: true, animate: !reduceMotion)
    }
}

@MainActor
private struct CalendarShellPresentations: ViewModifier {
    @EnvironmentObject private var viewModel: ReviewViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showHistory) {
                HistorySection(viewModel: viewModel)
                    .frame(width: 340, height: 420)
            }
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
