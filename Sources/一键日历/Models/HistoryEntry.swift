import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let creationDate: Date

    enum CodingKeys: String, CodingKey {
        case id, title, baseDate, reviewDates, creationDate
    }

    init(title: String, baseDate: Date, reviewDates: [Date], creationDate: Date) {
        self.id = UUID()
        self.title = title
        self.baseDate = baseDate
        self.reviewDates = reviewDates
        self.creationDate = creationDate
    }
}
