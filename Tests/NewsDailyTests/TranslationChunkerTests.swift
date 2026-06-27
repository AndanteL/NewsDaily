import XCTest
@testable import NewsDaily

final class TranslationChunkerTests: XCTestCase {
    func testExtractJSONFromPlainJSONObject() {
        let raw = #"{"title":"a","summary":"b"}"#
        XCTAssertEqual(TranslationService.extractJSON(from: raw), raw)
    }

    func testExtractJSONFromMarkdownFence() {
        let raw = """
        Sure, here is the translation:
        ```json
        {"title":"a","summary":"b"}
        ```
        """
        let extracted = TranslationService.extractJSON(from: raw)
        XCTAssertEqual(extracted, #"{"title":"a","summary":"b"}"#)
    }

    func testExtractJSONFromTextWithBraces() {
        let raw = "Pre text\n{\"translation\":\"你好\"}\nPost text"
        let extracted = TranslationService.extractJSON(from: raw)
        XCTAssertEqual(extracted, #"{"translation":"你好"}"#)
    }

    func testExtractJSONWithNoBracesReturnsNil() {
        XCTAssertNil(TranslationService.extractJSON(from: "no json here"))
    }

    func testArticlePromptContainsContent() {
        let prompt = TranslationService.articlePrompt(sourceLanguage: "en", targetLanguage: "zh-Hans", content: "Hello")
        XCTAssertTrue(prompt.system.contains("简体中文"))
        XCTAssertTrue(prompt.user.contains("Hello"))
    }

    func testDecodeArticleTranslationPayloadFromJSONFragment() {
        let raw = #"""
        "title_zh":"标题",
        "summary_zh":"导语",
        "body_zh":"第一段\n\n第二段"
        """#

        let payload = TranslationService.decodeArticleTranslationPayload(from: raw)

        XCTAssertEqual(payload?.titleZh, "标题")
        XCTAssertEqual(payload?.summaryZh, "导语")
        XCTAssertEqual(payload?.bodyZh, "第一段\n\n第二段")
    }

    func testCleanPlainTranslationConvertsEscapedNewlines() {
        let cleaned = TranslationService.cleanPlainTranslation("第一段\\n\\n第二段")

        XCTAssertEqual(cleaned, "第一段\n\n第二段")
    }

    func testSelectionPromptContainsContextAndText() {
        let prompt = TranslationService.selectionPrompt(selectedText: "war", context: "war in ukraine", targetLanguage: "zh-Hans")
        XCTAssertTrue(prompt.user.contains("war in ukraine"))
        XCTAssertTrue(prompt.user.contains("war"))
    }

    func testContentHashIsStable() {
        let h1 = TranslationCache.contentHash(title: "title", summary: "summary", body: nil)
        let h2 = TranslationCache.contentHash(title: "title", summary: "summary", body: nil)
        XCTAssertEqual(h1, h2)
    }
}
