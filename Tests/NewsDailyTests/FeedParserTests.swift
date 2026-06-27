import XCTest
@testable import NewsDaily

final class FeedParserTests: XCTestCase {
    private let parser = FeedParser()

    private func makeSource(id: String = "bbc-world", languageCode: String = "en") -> NewsSource {
        NewsSource.fromConfig(NewsSourceConfig(
            id: id, name: "BBC", homepage: "https://www.bbc.com",
            feedURL: "https://example.com/rss.xml",
            language: languageCode, region: "global"
        ))
    }

    func testParseRSS2_0() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>BBC News - World</title>
            <link>https://www.bbc.co.uk/news/world</link>
            <description>The latest stories from the World section</description>
            <item>
              <title>Story one</title>
              <description>First story summary</description>
              <link>https://www.bbc.co.uk/news/world-1</link>
              <guid>https://www.bbc.co.uk/news/world-1</guid>
              <pubDate>Fri, 27 Jun 2025 10:00:00 GMT</pubDate>
            </item>
            <item>
              <title>Story two</title>
              <description>Second story summary with &amp; ampersand</description>
              <link>https://www.bbc.co.uk/news/world-2</link>
              <pubDate>Fri, 27 Jun 2025 11:00:00 +0000</pubDate>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let drafts = try parser.parse(data: data, source: makeSource())
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].title, "Story one")
        XCTAssertEqual(drafts[0].summary, "First story summary")
        XCTAssertEqual(drafts[0].urlString, "https://www.bbc.co.uk/news/world-1")
        XCTAssertNotNil(drafts[0].publishedAt)
        XCTAssertEqual(drafts[1].summary, "Second story summary with & ampersand")
        XCTAssertNil(drafts[1].guid)
    }

    func testParseAtom() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Example Feed</title>
          <entry>
            <title>Atom entry one</title>
            <link href="https://example.com/entry1" />
            <id>urn:uuid:1</id>
            <updated>2025-06-27T12:00:00Z</updated>
            <summary>First atom summary</summary>
          </entry>
        </feed>
        """
        let data = xml.data(using: .utf8)!
        let drafts = try parser.parse(data: data, source: makeSource(id: "atom-feed"))
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].title, "Atom entry one")
        XCTAssertEqual(drafts[0].urlString, "https://example.com/entry1")
        XCTAssertEqual(drafts[0].guid, "urn:uuid:1")
        XCTAssertNotNil(drafts[0].publishedAt)
    }

    func testParseMalformedThrows() {
        let xml = "not xml"
        XCTAssertThrowsError(try parser.parse(data: xml.data(using: .utf8)!, source: makeSource()))
    }

    func testEmptyChannelParsesEmpty() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><title>x</title></channel></rss>
        """
        let data = xml.data(using: .utf8)!
        let drafts = try parser.parse(data: data, source: makeSource())
        XCTAssertEqual(drafts.count, 0)
    }

    func testFeedDateParser() {
        XCTAssertNotNil(FeedDateParser.parse("Fri, 27 Jun 2025 10:00:00 GMT"))
        XCTAssertNotNil(FeedDateParser.parse("2025-06-27T10:00:00Z"))
        XCTAssertNotNil(FeedDateParser.parse("2025-06-27T10:00:00+08:00"))
        XCTAssertNil(FeedDateParser.parse("not a date"))
    }
}
