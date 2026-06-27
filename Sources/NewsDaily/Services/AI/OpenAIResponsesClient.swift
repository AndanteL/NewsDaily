import Foundation

struct OpenAIResponsesClient: AIProviderClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateText(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        apiKey: String
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AIProviderError.missingAPIKey }
        guard let baseURL = config.baseURL else { throw AIProviderError.invalidConfig("baseURL 无效") }
        let endpoint = baseURL.appendingPathComponent("responses")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.applyAuth(apiKey: apiKey)
        request.timeoutInterval = config.timeoutSeconds

        let input = messages.map { ["role": $0.role, "content": $0.content] }
        var payload: [String: Any] = [
            "model": config.modelID,
            "input": input,
            "temperature": config.temperature,
            "max_output_tokens": config.maxOutputTokens
        ]
        if let extra = config.extraParameters {
            for (k, v) in extra { payload[k] = v }
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIProviderError.invalidResponse }
            if http.statusCode == 429 {
                let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                throw AIProviderError.rateLimited(retryAfter: retry)
            }
            guard 200..<300 ~= http.statusCode else {
                let body = String(data: data, encoding: .utf8)
                throw AIProviderError.requestFailed(statusCode: http.statusCode, body: body)
            }
            return try Self.extractOutputText(from: data)
        } catch let e as AIProviderError {
            throw e
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw AIProviderError.timeout
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw AIProviderError.cancelled
        } catch {
            throw AIProviderError.httpError(error)
        }
    }

    func streamText(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIProviderError.streamingNotImplemented)
        }
    }

    static func extractOutputText(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.decodingFailed("响应不是 JSON")
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw AIProviderError.providerError(message)
        }
        if let outputText = json["output_text"] as? String { return outputText }
        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for c in content {
                        if let text = c["text"] as? String { return text }
                    }
                }
            }
        }
        throw AIProviderError.decodingFailed("无法在 Responses 响应中找到文本")
    }
}
