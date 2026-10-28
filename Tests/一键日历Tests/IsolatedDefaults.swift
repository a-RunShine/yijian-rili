import Foundation
import XCTest

@testable import 一键日历

@MainActor
final class IsolatedDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init(file: StaticString = #filePath, line: UInt = #line) {
        suiteName = "one-click-calendar-tests-\(UUID().uuidString)"
        if let created = UserDefaults(suiteName: suiteName) {
            defaults = created
            created.removePersistentDomain(forName: suiteName)
        } else {
            XCTFail("无法创建独立 UserDefaults suite", file: file, line: line)
            defaults = .standard
        }
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
extension XCTestCase {
    func makeIsolatedDefaults(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> IsolatedDefaults {
        IsolatedDefaults(file: file, line: line)
    }

    func makeIsolatedViewModel(
        calendar: CalendarService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (ReviewViewModel, IsolatedDefaults) {
        let isolated = makeIsolatedDefaults(file: file, line: line)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: isolated.defaults)
        return (viewModel, isolated)
    }
}
