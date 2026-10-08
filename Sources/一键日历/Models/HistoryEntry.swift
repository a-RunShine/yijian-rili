import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let creationDate: Date
    let type: ScheduleType

    enum ScheduleType: String, Codable {
        case review
        case single
    }

    enum CodingKeys: String, CodingKey {
        case id, title, baseDate, reviewDates, creationDate, type
    }

    init(title: String,
         baseDate: Date,
         reviewDates: [Date],
         creationDate: Date,
         type: ScheduleType = .review) {
        self.id = UUID()
        self.title = title
        self.baseDate = baseDate
        self.reviewDates = reviewDates
        self.creationDate = creationDate
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        baseDate = try c.decode(Date.self, forKey: .baseDate)
        reviewDates = try c.decode([Date].self, forKey: .reviewDates)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        type = try c.decodeIfPresent(ScheduleType.self, forKey: .type) ?? .review
    }
}
