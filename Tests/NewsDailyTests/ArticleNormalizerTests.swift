import XCTest
@testable import NewsDaily

final class ArticleNormalizerTests: XCTestCase {
    func testCanonicalURLStripsTrackingParams() {
        let raw = "https://www.bbc.com/news/world-123?utm_source=twitter&utm_medium=social&fbclid=abc&keep=this"
        let canonical = ArticleNormalizer.canonicalURL(raw)
        XCTAssertEqual(canonical, "https://www.bbc.com/news/world-123?keep=this")
    }

    func testCanonicalURLLowercaseHost() {
        let raw = "https://WWW.Example.COM/Path/"
        let canonical = ArticleNormalizer.canonicalURL(raw)
        XCTAssertEqual(canonical, "https://www.example.com/Path")
    }

    func testCanonicalURLRemovesFragment() {
        let raw = "https://example.com/path#section"
        let canonical = ArticleNormalizer.canonicalURL(raw)
        XCTAssertEqual(canonical, "https://example.com/path")
    }

    func testArticleIDStableForSameURL() {
        let id1 = ArticleNormalizer.articleID(sourceID: "src", urlString: "https://example.com/a?utm_source=x", guid: nil)
        let id2 = ArticleNormalizer.articleID(sourceID: "src", urlString: "https://example.com/a", guid: nil)
        XCTAssertEqual(id1, id2)
    }

    func testArticleIDPrefersGUID() {
        let id1 = ArticleNormalizer.articleID(sourceID: "src", urlString: "https://example.com/a", guid: "guid-1")
        let id2 = ArticleNormalizer.articleID(sourceID: "src", urlString: "https://example.com/b", guid: "guid-1")
        XCTAssertEqual(id1, id2)
    }

    func testContentHashStable() {
        let h1 = ArticleNormalizer.contentHash(title: "title", summary: "summary")
        let h2 = ArticleNormalizer.contentHash(title: "title", summary: "summary")
        XCTAssertEqual(h1, h2)
        let h3 = ArticleNormalizer.contentHash(title: "title2", summary: "summary")
        XCTAssertNotEqual(h1, h3)
    }

    func testSimilarity() {
        let s1 = ArticleNormalizer.similarity("Trump wins election", "Trump wins election in US")
        XCTAssertGreaterThan(s1, 0.5)
        let s2 = ArticleNormalizer.similarity("Apple releases new phone", "Russian army advances")
        XCTAssertLessThan(s2, 0.2)
    }
}
