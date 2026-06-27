import XCTest
@testable import NewsDaily

final class AIProviderClientTests: XCTestCase {
    func testFactoryReturnsCorrectClient() {
        let factory = AIProviderClientFactory()
        XCTAssertTrue(factory.makeClient(for: .openAICompatibleChat) is OpenAICompatibleChatClient)
        XCTAssertTrue(factory.makeClient(for: .openAIResponses) is OpenAIResponsesClient)
        XCTAssertTrue(factory.makeClient(for: .customHTTP) is CustomHTTPAIClient)
    }

    func testExtractTextFromOpenAIResponse() throws {
        let json = """
        {"choices":[{"message":{"role":"assistant","content":"你好"}}]}
        """
        let data = json.data(using: .utf8)!
        let text = try OpenAICompatibleResponseParser.extractText(from: data)
        XCTAssertEqual(text, "你好")
    }

    func testExtractTextFromTextResponse() throws {
        let json = """
        {"choices":[{"text":"Hello world"}]}
        """
        let data = json.data(using: .utf8)!
        let text = try OpenAICompatibleResponseParser.extractText(from: data)
        XCTAssertEqual(text, "Hello world")
    }

    func testExtractTextThrowsOnError() {
        let json = #"{"error":{"message":"Invalid key"}}"#
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try OpenAICompatibleResponseParser.extractText(from: data))
    }

    func testExtractDeltaFromStreamChunk() throws {
        let json = #"{"choices":[{"delta":{"content":"foo"}}]}"#
        let data = json.data(using: .utf8)!
        let delta = try OpenAICompatibleResponseParser.extractDelta(from: data)
        XCTAssertEqual(delta, "foo")
    }

    func testExtractDeltaNilOnEmpty() throws {
        let json = #"{"choices":[{"delta":{}}]}"#
        let data = json.data(using: .utf8)!
        let delta = try OpenAICompatibleResponseParser.extractDelta(from: data)
        XCTAssertNil(delta)
    }

    func testRequestBuilderIncludesAllFields() throws {
        let config = AIProviderConfig(
            displayName: "x", kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://x", modelID: "m", apiKey: "test-api-key",
            maxOutputTokens: 100, temperature: 0.3,
            extraParametersJSON: #"{"top_p":0.9}"#
        )
        let runtime = ProviderRuntimeConfig(config)
        let data = try AIRequestBuilder.body(messages: [.user("hi")], config: runtime)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "m")
        XCTAssertEqual(json?["temperature"] as? Double, 0.3)
        XCTAssertEqual(json?["max_tokens"] as? Int, 100)
        XCTAssertEqual(json?["top_p"] as? Double, 0.9)
    }

    func testTranslationRuntimeConfigDisablesReasoningForChatProviders() throws {
        let config = AIProviderConfig(
            displayName: "小米 MiMo",
            kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://x",
            modelID: "mimo",
            apiKey: "test-api-key"
        )
        let runtime = ProviderRuntimeConfig(config).disablingReasoningForTranslation()
        let data = try AIRequestBuilder.body(messages: [.user("translate")], config: runtime)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["enable_thinking"] as? Bool, false)
        XCTAssertEqual(json?["reasoning_effort"] as? String, "low")
        XCTAssertEqual((json?["thinking"] as? [String: Any])?["type"] as? String, "disabled")
    }

    func testTranslationRuntimeConfigKeepsUserReasoningOverrides() throws {
        let config = AIProviderConfig(
            displayName: "custom",
            kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://x",
            modelID: "custom",
            apiKey: "test-api-key",
            extraParametersJSON: #"{"enable_thinking":true,"reasoning_effort":"low"}"#
        )
        let runtime = ProviderRuntimeConfig(config).disablingReasoningForTranslation()
        let data = try AIRequestBuilder.body(messages: [.user("translate")], config: runtime)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["enable_thinking"] as? Bool, true)
        XCTAssertEqual(json?["reasoning_effort"] as? String, "low")
    }
}
