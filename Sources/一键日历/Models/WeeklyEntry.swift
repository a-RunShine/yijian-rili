import Foundation

struct WeeklyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let baseDate: Date
    let scheduleType: HistoryEntry.ScheduleType
    let creationDate: Date
    let isPreOccupiedNextWeek: Bool

    init(id: UUID,
         title: String,
         baseDate: Date,
         scheduleType: HistoryEntry.ScheduleType,
         creationDate: Date,
         isPreOccupiedNextWeek: Bool = false) {
        self.id = id
        self.title = title
        self.baseDate = baseDate
        self.scheduleType = scheduleType
        self.creationDate = creationDate
        self.isPreOccupiedNextWeek = isPreOccupiedNextWeek
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, baseDate, scheduleType, creationDate, isPreOccupiedNextWeek
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        baseDate = try c.decode(Date.self, forKey: .baseDate)
        scheduleType = try c.decode(HistoryEntry.ScheduleType.self, forKey: .scheduleType)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        isPreOccupiedNextWeek = try c.decodeIfPresent(Bool.self, forKey: .isPreOccupiedNextWeek) ?? false
    }
}
