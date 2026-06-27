import XCTest
@testable import NewsDaily

final class SourceRegistryTests: XCTestCase {
    func testExtractFeedLinkFromLinkTag() {
        let html = """
        <html><head>
          <link rel="alternate" type="application/rss+xml" title="RSS" href="/feed.xml" />
        </head></html>
        """
        let base = URL(string: "https://example.com")!
        let url = SourceRegistry.extractFeedLink(from: html, baseURL: base)
        XCTAssertEqual(url?.absoluteString, "https://example.com/feed.xml")
    }

    func testExtractFeedLinkFromAtom() {
        let html = """
        <link rel="alternate" type="application/atom+xml" href="https://example.com/atom" />
        """
        let base = URL(string: "https://example.com")!
        let url = SourceRegistry.extractFeedLink(from: html, baseURL: base)
        XCTAssertEqual(url?.absoluteString, "https://example.com/atom")
    }

    func testExtractFeedLinkReturnsNilWhenAbsent() {
        let html = "<html></html>"
        let base = URL(string: "https://example.com")!
        XCTAssertNil(SourceRegistry.extractFeedLink(from: html, baseURL: base))
    }

    func testLoadBuiltinSourcesFromBundle() throws {
        let url = Bundle.module.url(forResource: "sources", withExtension: "json")
        XCTAssertNotNil(url)
        guard let url else { return }
        let data = try Data(contentsOf: url)
        let configs = try JSONDecoder().decode([NewsSourceConfig].self, from: data)
        XCTAssertFalse(configs.isEmpty)
        XCTAssertTrue(configs.contains { $0.id == "bbc-world" })
    }

    func testLoadBuiltinAIProvidersFromBundle() throws {
        let url = Bundle.module.url(forResource: "ai-providers", withExtension: "json")
        XCTAssertNotNil(url)
        guard let url else { return }
        let data = try Data(contentsOf: url)
        let templates = try JSONDecoder().decode([AIProviderTemplate].self, from: data)
        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.contains { $0.id == "deepseek" })
    }
}
