import XCTest
@testable import NewsDaily

final class AIProviderConfigTests: XCTestCase {
    func testAPIKeyIsStoredOnProviderConfig() {
        let provider = AIProviderConfig(
            displayName: "DeepSeek",
            kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://api.deepseek.com/v1",
            modelID: "deepseek-chat",
            apiKey: "test-api-key-local-config"
        )

        XCTAssertEqual(provider.apiKey, "test-api-key-local-config")
    }

    func testAPIKeyCanBeUpdatedOnProviderConfig() {
        let provider = AIProviderConfig(
            displayName: "智谱 GLM",
            kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://open.bigmodel.cn/api/paas/v4",
            modelID: "glm-4-flash"
        )

        provider.apiKey = "test-api-key-updated-config"

        XCTAssertEqual(provider.apiKey, "test-api-key-updated-config")
    }
}
