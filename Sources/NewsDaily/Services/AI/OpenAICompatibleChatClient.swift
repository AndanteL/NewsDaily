import Foundation

struct OpenAICompatibleChatClient: AIProviderClient {
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
        let endpoint = baseURL.appendingPathComponent("chat").appendingPathComponent("completions")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.applyAuth(apiKey: apiKey)
        request.timeoutInterval = config.timeoutSeconds
        request.httpBody = try AIRequestBuilder.body(messages: messages, config: config)

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
            let task = Task {
                do {
                    guard !apiKey.isEmpty else {
                        continuation.finish(throwing: AIProviderError.missingAPIKey)
                        return
                    }
                    guard let baseURL = config.baseURL else {
                        continuation.finish(throwing: AIProviderError.invalidConfig("baseURL 无效"))
                        return
                    }
                    let endpoint = baseURL.appendingPathComponent("chat").appendingPathComponent("completions")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.applyAuth(apiKey: apiKey)
                    request.timeoutInterval = config.timeoutSeconds
                    request.httpBody = try AIRequestBuilder.body(messages: messages, config: config, stream: true)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIProviderError.invalidResponse)
                        return
                    }
                    if http.statusCode == 429 {
                        let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
                        continuation.finish(throwing: AIProviderError.rateLimited(retryAfter: retry))
                        return
                    }
                    guard 200..<300 ~= http.statusCode else {
                        continuation.finish(throwing: AIProviderError.requestFailed(statusCode: http.statusCode, body: nil))
                        return
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: AIProviderError.cancelled)
                            return
                        }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let delta = (try? OpenAICompatibleResponseParser.extractDelta(from: data)) ?? nil {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch let e as AIProviderError {
                    continuation.finish(throwing: e)
                } catch let urlError as URLError where urlError.code == .timedOut {
                    continuation.finish(throwing: AIProviderError.timeout)
                } catch let urlError as URLError where urlError.code == .cancelled {
                    continuation.finish(throwing: AIProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: AIProviderError.httpError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
