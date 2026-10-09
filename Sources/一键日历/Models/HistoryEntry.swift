import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let creationDate: Date
    let type: ScheduleType
    let createdEventIdentifiers: [String]
    let sharedDetail: String?

    enum ScheduleType: String, Codable {
        case review
        case single
    }

    enum CodingKeys: String, CodingKey {
        case id, title, baseDate, reviewDates, creationDate, type
        case createdEventIdentifiers, sharedDetail
    }

    init(id: UUID = UUID(),
         title: String,
         baseDate: Date,
         reviewDates: [Date],
         creationDate: Date,
         type: ScheduleType = .review,
         createdEventIdentifiers: [String] = [],
         sharedDetail: String? = nil) {
        self.id = id
        self.title = title
        self.baseDate = baseDate
        self.reviewDates = reviewDates
        self.creationDate = creationDate
        self.type = type
        self.createdEventIdentifiers = createdEventIdentifiers
        self.sharedDetail = sharedDetail
    }

    func withSharedDetail(_ detail: String?) -> HistoryEntry {
        HistoryEntry(
            id: id,
            title: title,
            baseDate: baseDate,
            reviewDates: reviewDates,
            creationDate: creationDate,
            type: type,
            createdEventIdentifiers: createdEventIdentifiers,
            sharedDetail: detail
        )
    }

    func withCreatedEventIdentifiers(_ identifiers: [String]) -> HistoryEntry {
        HistoryEntry(
            id: id,
            title: title,
            baseDate: baseDate,
            reviewDates: reviewDates,
            creationDate: creationDate,
            type: type,
            createdEventIdentifiers: identifiers,
            sharedDetail: sharedDetail
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        baseDate = try c.decode(Date.self, forKey: .baseDate)
        reviewDates = try c.decode([Date].self, forKey: .reviewDates)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        type = try c.decodeIfPresent(ScheduleType.self, forKey: .type) ?? .review
        createdEventIdentifiers = try c.decodeIfPresent([String].self, forKey: .createdEventIdentifiers) ?? []
        sharedDetail = try c.decodeIfPresent(String.self, forKey: .sharedDetail)
    }
}
