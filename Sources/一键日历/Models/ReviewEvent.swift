import Foundation
import OSLog

struct ReviewEvent: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, baseDate, reviewDates, notes
    }

    init(title: String, baseDate: Date, intervals: [Int] = [3, 7, 30]) {
        self.id = UUID()
        self.title = title
        self.baseDate = baseDate
        let dates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        self.reviewDates = dates
        // notes 数量与 reviewDates 对齐，而非 intervals
        self.notes = dates.enumerated().map { index, _ in
            "第\(index + 1)次复习"
        }
    }

    static func calculateReviewDates(from baseDate: Date, intervals: [Int] = [3, 7, 30]) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        for interval in intervals {
            if let date = calendar.date(byAdding: .day, value: interval, to: baseDate) {
                dates.append(date)
            } else {
                Logger(subsystem: "com.yijianrili.app", category: "ReviewEvent")
                    .warning("Failed to calculate date for interval \(interval) from \(baseDate)")
            }
        }

        return dates
    }
}
