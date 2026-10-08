import Foundation

/// 日程浏览：按日列表与标题搜索（含按 id 删除）。
@MainActor
final class DayBrowseModel {
    enum DayType: String, CaseIterable, Identifiable {
        case yesterday
        case today
        case tomorrow

        var id: String { rawValue }

        var label: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_button", comment: "")
            case .today: return NSLocalizedString("today_button", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_button", comment: "")
            }
        }

        var dayOffset: Int {
            switch self {
            case .yesterday: return -1
            case .today: return 0
            case .tomorrow: return 1
            }
        }

        var sectionTitle: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_events", comment: "")
            case .today: return NSLocalizedString("today_events", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_events", comment: "")
            }
        }

        var emptyHint: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_no_events", comment: "")
            case .today: return NSLocalizedString("today_no_events", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_no_events", comment: "")
            }
        }
    }

    private let calendar: CalendarService

    var selectedDayType: DayType = .today
    var displayedEvents: [CalendarEventInfo] = []
    var searchText: String = ""
    var searchResults: [CalendarEventInfo] = []
    var selectedSearchResult: CalendarEventInfo?

    var displayedDate: Date {
        date(for: selectedDayType)
    }

    init(calendar: CalendarService) {
        self.calendar = calendar
    }

    func date(for dayType: DayType) -> Date {
        Calendar.current.date(byAdding: .day, value: dayType.dayOffset, to: Date()) ?? Date()
    }

    func loadDisplayedDayEvents() {
        displayedEvents = calendar.fetchEvents(on: displayedDate)
    }

    func selectDayType(_ dayType: DayType) {
        selectedDayType = dayType
        loadDisplayedDayEvents()
    }

    func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        searchResults = calendar.searchEvents(query: trimmed, daysAhead: 90)
    }

    @discardableResult
    func deleteSearchResult(_ event: CalendarEventInfo) -> Bool {
        let success = calendar.deleteEvent(id: event.id)
        if success {
            searchResults.removeAll { $0.id == event.id }
            if selectedSearchResult?.id == event.id {
                selectedSearchResult = nil
            }
            loadDisplayedDayEvents()
        }
        return success
    }

    func resetSearch() {
        searchText = ""
        searchResults = []
        selectedSearchResult = nil
    }
}
