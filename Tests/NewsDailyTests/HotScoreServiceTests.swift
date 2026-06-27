import XCTest
@testable import NewsDaily

final class HotScoreServiceTests: XCTestCase {
    func testRecencyDecaysOverTime() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let svc = HotScoreService(now: now)
        let recent = svc.recencyScore(publishedAt: now)
        let oldDate = now.addingTimeInterval(-72 * 3600)
        let old = svc.recencyScore(publishedAt: oldDate)
        XCTAssertEqual(recent, 1.0, accuracy: 0.001)
        XCTAssertLessThan(old, 0.1)
    }

    func testKeywordScore() {
        let svc = HotScoreService()
        XCTAssertEqual(svc.keywordScore(keywords: []), 0)
        let s = svc.keywordScore(keywords: ["war", "election"])
        XCTAssertGreaterThan(s, 0)
    }

    func testDuplicateTopicScore() {
        let svc = HotScoreService()
        XCTAssertEqual(svc.duplicateTopicScore(count: 0), 0)
        XCTAssertEqual(svc.duplicateTopicScore(count: 1), 0.4)
        XCTAssertEqual(svc.duplicateTopicScore(count: 2), 0.7)
        XCTAssertEqual(svc.duplicateTopicScore(count: 5), 1.0)
    }

    func testComputeTotalScore() {
        let svc = HotScoreService()
        let now = Date()
        let score1 = svc.compute(publishedAt: now, sourceWeight: 1.0, keywords: ["war"], duplicatesInOtherSources: 0)
        let score2 = svc.compute(publishedAt: now.addingTimeInterval(-48 * 3600), sourceWeight: 1.0, keywords: [], duplicatesInOtherSources: 0)
        XCTAssertGreaterThan(score1, score2)
    }

    func testExtractKeywords() {
        let kws = HotScoreService.extractKeywords(from: "Apple announces new AI product amid market turmoil", summary: nil)
        XCTAssertContains(kws, "ai")
        XCTAssertContains(kws, "apple")
        XCTAssertContains(kws, "market")
    }
}

func XCTAssertContains<T: Equatable>(_ array: [T], _ element: T) {
    if !array.contains(element) {
        XCTFail("Expected array \(array) to contain \(element)")
    }
}
