import AppKit
import SwiftUI

@MainActor
struct MonthDayCell: View {
    @EnvironmentObject private var viewModel: ReviewViewModel
    let cell: MonthCell
    let mode: CanvasMode
    let events: [CalendarEventInfo]
    let previewOrdinal: Int?
    let rowHeight: CGFloat
    let palette: ThemePalette
    var onMonthGridFocus: (Bool) -> Void = { _ in }

    @State private var isHovered = false
    @State private var lastClickDate: Date?
    @State private var lastClickTime: Date = .distantPast

    private let cornerRadius: CGFloat = 8

    var body: some View {
        contents
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: mode == .wide ? .topLeading : .center)
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(palette.separator, lineWidth: 1)
                }
            }
            .opacity(cell.isInDisplayedMonth ? 1 : 0.45)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onTapGesture(count: 1, perform: selectDay)
            .onHover { isHovered = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selectDay() }
    }

    @ViewBuilder
    private var contents: some View {
        if mode == .wide {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 4) {
                    dayNumber
                    Spacer(minLength: 0)
                    if let previewOrdinal, !isSelected {
                        Text("\(previewOrdinal)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(palette.onAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                ForEach(Array(events.prefix(2))) { event in
                    Text(event.title)
                        .font(.caption)
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                }
                if events.count > 2 {
                    Text(String(format: NSLocalizedString("month_more_events", comment: ""), events.count - 2))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isSelected ? palette.onAccent : palette.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            VStack(spacing: 4) {
                dayNumber
                if !events.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(0..<min(events.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? palette.onAccent : palette.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
        }
    }

    private var dayNumber: some View {
        Text(String(WeekCalculator.calendar.component(.day, from: cell.date)))
            .font(.body.monospacedDigit())
            .foregroundStyle(foreground)
            .frame(minWidth: 22, minHeight: 22)
            .overlay {
                if cell.isToday {
                    Circle()
                        .strokeBorder(isSelected ? palette.onAccent : palette.primary, lineWidth: 1)
                }
            }
    }

    private var fill: Color {
        if isSelected {
            return palette.accent
        }
        if let previewOrdinal, mode == .wide {
            return palette.accent.opacity(MonthPreviewWindow.shadeOpacity(forOrdinal: previewOrdinal))
        }
        if isHovered {
            return palette.hover
        }
        return palette.card
    }

    private var foreground: Color {
        isSelected ? palette.onAccent : palette.primary
    }

    private var isSelected: Bool {
        cell.date == Calendar.current.startOfDay(for: viewModel.baseDate)
    }

    private var accessibilityLabel: String {
        let when = "\(formatted("yMMMd")) \(formatted("EEEE"))"
        let count = String(format: NSLocalizedString("month_cell_events", comment: ""), events.count)
        if let previewOrdinal {
            let ordinal = String(format: NSLocalizedString("review_count", comment: ""), "\(previewOrdinal)")
            return String(format: NSLocalizedString("month_cell_accessibility_preview", comment: ""), when, count, ordinal)
        }
        return String(format: NSLocalizedString("month_cell_accessibility", comment: ""), when, count)
    }

    private func formatted(_ template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = WeekCalculator.calendar
        formatter.timeZone = WeekCalculator.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: cell.date)
    }

    private func selectDay() {
        let now = Date()
        let isRepeatedClick = lastClickDate == cell.date
            && now.timeIntervalSince(lastClickTime) <= NSEvent.doubleClickInterval
        lastClickDate = isRepeatedClick ? nil : cell.date
        lastClickTime = now
        viewModel.selectDay(cell.date)
        if isRepeatedClick {
            focusTitle()
        } else {
            onMonthGridFocus(true)
        }
    }

    private func focusTitle() {
        onMonthGridFocus(false)
        NotificationCenter.default.post(name: .focusComposerTitle, object: nil)
    }
}
