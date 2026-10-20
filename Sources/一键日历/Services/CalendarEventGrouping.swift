import Foundation

enum CalendarEventGrouping {
    static func byDay(_ events: [CalendarEventInfo]) -> [Date: [CalendarEventInfo]] {
        let calendar = Calendar.current
        var grouped: [Date: [CalendarEventInfo]] = [:]
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            while day < event.end {
                grouped[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return grouped
    }
}
