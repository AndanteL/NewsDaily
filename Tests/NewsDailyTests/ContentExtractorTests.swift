import XCTest
@testable import NewsDaily

final class ContentExtractorTests: XCTestCase {
    func testExtractTitle() {
        let html = "<html><head><title>Hello World</title></head><body></body></html>"
        XCTAssertEqual(ContentExtractor.extractTitle(html: html), "Hello World")
    }

    func testExtractTitleFromOGTitle() {
        let html = """
        <meta property="og:title" content="OG Title" />
        """
        XCTAssertEqual(ContentExtractor.extractTitle(html: html), "OG Title")
    }

    func testExtractMetaContent() {
        let html = """
        <meta name="author" content="Jane Doe" />
        <meta name="description" content="Article description" />
        """
        XCTAssertEqual(ContentExtractor.extractMetaContent(html: html, name: "author"), "Jane Doe")
        XCTAssertEqual(ContentExtractor.extractMetaContent(html: html, name: "description"), "Article description")
    }

    func testStripTagsRemovesScriptsAndStyles() {
        let html = """
        <script>alert('x')</script>
        <style>body { color: red; }</style>
        <p>Visible content</p>
        """
        let stripped = ContentExtractor.stripTags(html: html)
        XCTAssertFalse(stripped.contains("alert"))
        XCTAssertFalse(stripped.contains("color: red"))
        XCTAssertTrue(stripped.contains("Visible content"))
    }

    func testDecodeEntities() {
        XCTAssertEqual(ContentExtractor.decodeEntities("Tom &amp; Jerry"), "Tom & Jerry")
        XCTAssertEqual(ContentExtractor.decodeEntities("a &nbsp; b"), "a   b")
        XCTAssertEqual(ContentExtractor.decodeEntities("&#65;"), "A")
        XCTAssertEqual(ContentExtractor.decodeEntities("Italy&#x27;s prime minister"), "Italy's prime minister")
    }

    func testExtractParagraphsFiltersShortText() {
        let html = "<p>short</p><p>This is a long paragraph that should be retained because it has enough length.</p>"
        let paras = ContentExtractor.extractParagraphs(html: html)
        XCTAssertTrue(paras.contains { $0.contains("long paragraph") })
    }

    func testExtractComplete() {
        let html = """
        <html><head>
          <title>Title</title>
          <meta name="author" content="Author" />
          <meta name="description" content="Excerpt" />
          <meta property="og:image" content="/images/lead.jpg" />
        </head><body>
          <p>First paragraph that is sufficiently long to be retained.</p>
          <p>Second paragraph with enough characters as well.</p>
          <img src="https://example.com/story-inline.jpg" />
        </body></html>
        """
        let extracted = ContentExtractor.extract(from: html, baseURL: URL(string: "https://example.com/news/story"))
        XCTAssertEqual(extracted.title, "Title")
        XCTAssertEqual(extracted.byline, "Author")
        XCTAssertEqual(extracted.excerpt, "Excerpt")
        XCTAssertGreaterThanOrEqual(extracted.paragraphs.count, 2)
        XCTAssertEqual(extracted.imageURLs, [
            "https://example.com/images/lead.jpg",
            "https://example.com/story-inline.jpg"
        ])
    }

    func testExtractImageURLsFromSrcset() {
        let html = #"<img srcset="/small.jpg 320w, /large.jpg 1024w" />"#
        let urls = ContentExtractor.extractImageURLs(html: html, baseURL: URL(string: "https://example.com/article"))

        XCTAssertEqual(urls, ["https://example.com/small.jpg"])
    }

    func testExtractParagraphsPrefersArticleAndDropsBBCNavigationNoise() {
        let html = """
        <html><body>
          <nav>HomepageSkip to contentAccessibility HelpYour accountHomeNewsSportEarthReelWorklifeTravelCultureFutureMusicTVWeatherSoundsMore menuMore menuSearch</nav>
          <article>
            <p>Image source, EPA-EFE/REX/Shutterstock</p>
            <p>Image caption, Relations between Italy&#x27;s prime minister and President Trump have worsened considerably since 2025</p>
            <p>There is an AI-generated meme doing the rounds on social media in Italy that shows Giorgia Meloni doing all the things you might expect from someone fresh out of a tough break-up.</p>
            <p>Of course none of the images are real, but the joke has landed because it captures the very public political fall-out between the Italian prime minister and US President Donald Trump.</p>
          </article>
        </body></html>
        """

        let paragraphs = ContentExtractor.extractParagraphs(html: html)

        XCTAssertEqual(paragraphs.count, 2)
        XCTAssertFalse(paragraphs.joined().contains("HomepageSkip"))
        XCTAssertFalse(paragraphs.joined().contains("Image source"))
        XCTAssertTrue(paragraphs[0].contains("AI-generated meme"))
    }

    func testSanitizeParagraphsDropsCachedNavigationBlob() {
        let paragraphs = ContentExtractor.sanitizeParagraphs([
            "BBC HomepageSkip to contentAccessibility HelpYour accountHomeNewsSportEarthReelWorklifeTravelCultureFutureMusicTVWeatherSoundsMore menuMore menuSearch",
            "This is a real article paragraph with enough words to be retained by the cleaner."
        ])

        XCTAssertEqual(paragraphs, ["This is a real article paragraph with enough words to be retained by the cleaner."])
    }
}
