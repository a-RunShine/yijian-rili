import SwiftUI

@MainActor
struct MonthDayAgenda: View {
    let date: Date
    let events: [CalendarEventInfo]
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(MonthDayTitle.string(from: date))
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(String(format: NSLocalizedString("month_agenda_count", comment: ""), events.count))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondary)
            }
            if events.isEmpty {
                Text(NSLocalizedString("month_agenda_empty", comment: ""))
                    .font(.callout)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(events.prefix(2))) { event in
                    Text(event.title)
                        .font(.callout)
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card)
    }
}

@MainActor
struct MonthCompactFooter: View {
    let monthCount: Int
    let baseDate: Date
    let dayCount: Int
    let palette: ThemePalette
    let createReview: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(String(format: NSLocalizedString("month_footer_month_count", comment: ""), monthCount))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(MonthDayTitle.string(from: baseDate))
                    .lineLimit(1)
                Text(String(format: NSLocalizedString("month_footer_day_count", comment: ""), dayCount))
                    .lineLimit(1)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.secondary)
            Button(action: createReview) {
                Text(NSLocalizedString("month_new_review", comment: ""))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(palette.chrome)
    }
}

@MainActor
struct MonthPreviewOverflowLine: View {
    let overflow: MonthPreviewOverflow
    let palette: ThemePalette

    var body: some View {
        Text(copy)
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    private var copy: String {
        overflow.localizedLine() ?? ""
    }
}

@MainActor
struct BaseDayEventList: View {
    @EnvironmentObject private var viewModel: ReviewViewModel
    let date: Date
    let events: [CalendarEventInfo]
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(MonthDayTitle.string(from: date))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(String(format: NSLocalizedString("month_agenda_count", comment: ""), events.count))
                    .lineLimit(1)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.secondary)
            if events.isEmpty {
                Text(NSLocalizedString("month_agenda_empty", comment: ""))
                    .font(.callout)
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events) { event in
                        row(event)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private func row(_ event: CalendarEventInfo) -> some View {
        let status = viewModel.occurrenceStatus(for: event.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                viewModel.beginSharedDetailEditFromBrowse(event)
            } label: {
                Text(event.title.isEmpty ? NSLocalizedString("untitled", comment: "") : event.title)
                    .font(.callout)
                    .foregroundStyle(palette.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                statusButton(
                    title: NSLocalizedString("occurrence_mark_done", comment: ""),
                    selected: status == .done
                ) {
                    viewModel.setOccurrenceStatus(
                        eventId: event.id,
                        status: status == .done ? .unmarked : .done
                    )
                }
                statusButton(
                    title: NSLocalizedString("occurrence_mark_skipped", comment: ""),
                    selected: status == .skipped
                ) {
                    viewModel.setOccurrenceStatus(
                        eventId: event.id,
                        status: status == .skipped ? .unmarked : .skipped
                    )
                }
                if status != .unmarked {
                    Text(status == .done
                         ? NSLocalizedString("occurrence_status_done", comment: "")
                         : NSLocalizedString("occurrence_status_skipped", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(selected ? palette.onAccent : palette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selected ? palette.accent : palette.chip, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}

@MainActor
struct MonthAccessDenied: View {
    let palette: ThemePalette
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("permission_denied", comment: ""))
                .font(.body)
                .foregroundStyle(palette.primary)
                .multilineTextAlignment(.center)
            Button(action: openSettings) {
                Text(NSLocalizedString("open_settings", comment: ""))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum MonthDayTitle {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = WeekCalculator.calendar
        formatter.timeZone = WeekCalculator.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter.string(from: date)
    }
}
