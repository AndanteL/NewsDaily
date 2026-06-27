import Foundation

struct CustomHTTPAIClient: AIProviderClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func generateText(
        messages: [AIMessage],
        config: ProviderRuntimeConfig,
        apiKey: String
    ) async throws -> String {
        guard let baseURL = config.baseURL else { throw AIProviderError.invalidConfig("baseURL 无效") }
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = config.timeoutSeconds

        var payload: [String: Any] = [
            "model": config.modelID,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": config.temperature,
            "max_tokens": config.maxOutputTokens
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
            return try OpenAICompatibleResponseParser.extractText(from: data)
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
}
