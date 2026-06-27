import Foundation

struct AIMessage: Codable, Hashable, Sendable {
    let role: String
    let content: String

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    static func system(_ content: String) -> AIMessage { AIMessage(role: "system", content: content) }
    static func user(_ content: String) -> AIMessage { AIMessage(role: "user", content: content) }
    static func assistant(_ content: String) -> AIMessage { AIMessage(role: "assistant", content: content) }
}

struct ProviderRuntimeConfig: Sendable {
    let id: String
    let kind: AIProviderKind
    let baseURLString: String
    let modelID: String
    let supportsStreaming: Bool
    let timeoutSeconds: Double
    let maxOutputTokens: Int
    let temperature: Double
    let extraParametersJSON: String?

    init(_ config: AIProviderConfig) {
        self.id = config.id
        self.kind = config.kind
        self.baseURLString = config.baseURLString
        self.modelID = config.modelID
        self.supportsStreaming = config.supportsStreaming
        self.timeoutSeconds = config.timeoutSeconds
        self.maxOutputTokens = config.maxOutputTokens
        self.temperature = config.temperature
        self.extraParametersJSON = config.extraParametersJSON
    }

    init(
        id: String,
        kind: AIProviderKind,
        baseURLString: String,
        modelID: String,
        supportsStreaming: Bool,
        timeoutSeconds: Double,
        maxOutputTokens: Int,
        temperature: Double,
        extraParametersJSON: String?
    ) {
        self.id = id
        self.kind = kind
        self.baseURLString = baseURLString
        self.modelID = modelID
        self.supportsStreaming = supportsStreaming
        self.timeoutSeconds = timeoutSeconds
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.extraParametersJSON = extraParametersJSON
    }

    var baseURL: URL? { URL(string: baseURLString) }

    var extraParameters: [String: Any]? {
        guard let json = extraParametersJSON, !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func disablingReasoningForTranslation() -> ProviderRuntimeConfig {
        var extra = extraParameters ?? [:]
        switch kind {
        case .openAIResponses:
            if extra["reasoning"] == nil {
                extra["reasoning"] = ["effort": "minimal"]
            }
        case .openAICompatibleChat, .customHTTP:
            if extra["enable_thinking"] == nil {
                extra["enable_thinking"] = false
            }
            if extra["thinking"] == nil {
                extra["thinking"] = ["type": "disabled"]
            }
            if extra["reasoning_effort"] == nil {
                extra["reasoning_effort"] = "low"
            }
        }
        return ProviderRuntimeConfig(
            id: id,
            kind: kind,
            baseURLString: baseURLString,
            modelID: modelID,
            supportsStreaming: supportsStreaming,
            timeoutSeconds: timeoutSeconds,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            extraParametersJSON: Self.encodeExtraParameters(extra)
        )
    }

    private static func encodeExtraParameters(_ extra: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(extra),
              let data = try? JSONSerialization.data(withJSONObject: extra),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }
}

enum AIProviderError: LocalizedError {
    case invalidConfig(String)
    case missingAPIKey
    case invalidResponse
    case requestFailed(statusCode: Int, body: String?)
    case decodingFailed(String)
    case streamingNotImplemented
    case rateLimited(retryAfter: Double?)
    case timeout
    case cancelled
    case httpError(Error)
    case providerError(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfig(let s): return "Provider 配置无效: \(s)"
        case .missingAPIKey: return "缺少 API Key，请在设置中填写"
        case .invalidResponse: return "Provider 返回格式无法解析"
        case .requestFailed(let code, let body): return "请求失败 (HTTP \(code))\(body.map { ": \($0)" } ?? "")"
        case .decodingFailed(let s): return "响应解码失败: \(s)"
        case .streamingNotImplemented: return "该 Provider 暂不支持流式输出"
        case .rateLimited(let retry): return "请求被限流\(retry.map { "，建议 \($0) 秒后重试" } ?? "")"
        case .timeout: return "请求超时"
        case .cancelled: return "请求已取消"
        case .httpError(let e): return "网络错误: \(e.localizedDescription)"
        case .providerError(let s): return s
        }
    }
}

protocol AIProviderClient: Sendable {
    func generateText(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        apiKey: String
    ) async throws -> String

    func streamText(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error>
}

struct AIProviderClientFactory {
    func makeClient(for kind: AIProviderKind) -> AIProviderClient {
        switch kind {
        case .openAICompatibleChat: return OpenAICompatibleChatClient()
        case .openAIResponses: return OpenAIResponsesClient()
        case .customHTTP: return CustomHTTPAIClient()
        }
    }
}

enum OpenAICompatibleResponseParser {
    static func extractText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.decodingFailed("响应不是 JSON")
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw AIProviderError.providerError(message)
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            throw AIProviderError.decodingFailed("缺少 choices")
        }
        if let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        if let text = first["text"] as? String {
            return text
        }
        throw AIProviderError.decodingFailed("缺少 message.content")
    }

    static func extractDelta(from data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let choices = json["choices"] as? [[String: Any]],
           let first = choices.first {
            if let delta = first["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                return content
            }
            if let text = first["text"] as? String {
                return text
            }
        }
        return nil
    }
}

extension URLRequest {
    mutating func applyAuth(apiKey: String) {
        setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}

enum AIRequestBuilder {
    static func body(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        stream: Bool = false,
        responseFormatJSON: Bool = false
    ) throws -> Data {
        var payload: [String: Any] = [
            "model": config.modelID,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": config.temperature,
            "max_tokens": config.maxOutputTokens
        ]
        if stream { payload["stream"] = true }
        if responseFormatJSON {
            payload["response_format"] = ["type": "json_object"]
        }
        if let extra = config.extraParameters {
            for (k, v) in extra { payload[k] = v }
        }
        return try JSONSerialization.data(withJSONObject: payload)
    }
}
