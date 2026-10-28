import XCTest

final class CalendarCommitInvariantTests: XCTestCase {
    private var source: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/一键日历/Services/CalendarManager.swift")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    func testEveryRemoveIsFollowedByCommit() throws {
        let lines = try source.split(separator: "\n", omittingEmptySubsequences: false)
        var removals: [Int] = []
        for (index, line) in lines.enumerated() where line.contains("eventStore.remove(") {
            removals.append(index)
        }
        XCTAssertFalse(
            removals.isEmpty,
            "没找到任何 remove 调用，说明这个检查已经失效，需要更新匹配规则"
        )

        for index in removals {
            let window = lines[index...min(index + 4, lines.count - 1)].joined(separator: "\n")
            XCTAssertTrue(
                window.contains("eventStore.commit()"),
                "第 \(index + 1) 行的 remove 后面 4 行内没有 commit()。删改只进队列不提交，日历里实际不会变。"
            )
        }
    }

    func testEverySaveIsFollowedByCommit() throws {
        let lines = try source.split(separator: "\n", omittingEmptySubsequences: false)
        var saves: [Int] = []
        for (index, line) in lines.enumerated() where line.contains("eventStore.save(") {
            saves.append(index)
        }
        XCTAssertFalse(
            saves.isEmpty,
            "没找到任何 save 调用，说明这个检查已经失效，需要更新匹配规则"
        )

        for index in saves {
            let window = lines[index...min(index + 4, lines.count - 1)].joined(separator: "\n")
            XCTAssertTrue(
                window.contains("eventStore.commit()"),
                "第 \(index + 1) 行的 save 后面 4 行内没有 commit()。写入只进队列不提交，事件不会真正落库。"
            )
        }
    }
}
