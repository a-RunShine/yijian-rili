import Foundation

enum OccurrenceStatus: String, Codable, Equatable, Sendable {
    case unmarked
    case done
    case skipped
}

struct OccurrenceReviewMaterial: Equatable, Identifiable, Sendable {
    var id: String { eventId }
    let eventId: String
    let title: String
    let occurrenceDate: Date
    let status: OccurrenceStatus
}
