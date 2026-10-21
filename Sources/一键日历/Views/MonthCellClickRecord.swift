import Foundation

struct MonthCellClickRecord: Equatable {
    let day: Date
    let time: Date

    static func register(
        previous: MonthCellClickRecord?,
        day: Date,
        at now: Date,
        within interval: TimeInterval
    ) -> (next: MonthCellClickRecord?, isRepeated: Bool) {
        let isRepeated = previous?.day == day
            && previous.map { now.timeIntervalSince($0.time) <= interval } == true
        guard !isRepeated else { return (nil, true) }
        return (MonthCellClickRecord(day: day, time: now), false)
    }
}
