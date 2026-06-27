import XCTest
@testable import NewsDaily

final class ReaderTabTests: XCTestCase {
    func testReaderTabsHaveVisibleTitles() {
        let titles = ReaderView.ReaderTab.allCases.map(\.title)

        XCTAssertEqual(titles, ["原文正文", "AI 翻译", "双语对照", "网页全文"])
        XCTAssertFalse(titles.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testReaderTabsHaveHelpText() {
        let helpTexts = ReaderView.ReaderTab.allCases.map(\.helpText)

        XCTAssertEqual(helpTexts.count, ReaderView.ReaderTab.allCases.count)
        XCTAssertFalse(helpTexts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}
