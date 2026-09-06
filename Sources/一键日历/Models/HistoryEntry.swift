import Foundation

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let creationDate: Date
    /// spec F9: 新增字段。旧数据缺少时默认 `.review`（自定义解码兼容）
    let type: ScheduleType

    /// 日程类型：复习计划 / 单次日程（spec F4, plan §2.2）
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

    /// 自定义解码：缺失 `type` 字段时默认 `.review`（满足 spec F9 旧数据兼容）
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
