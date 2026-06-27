import Foundation
import SwiftData

enum AIProviderKind: String, Codable, CaseIterable, Sendable {
    case openAICompatibleChat
    case openAIResponses
    case customHTTP

    var displayName: String {
        switch self {
        case .openAICompatibleChat: return "OpenAI 兼容 Chat Completions"
        case .openAIResponses: return "OpenAI Responses API"
        case .customHTTP: return "自定义 HTTP"
        }
    }
}

@Model
final class AIProviderConfig {
    @Attribute(.unique) var id: String
    var displayName: String
    var kindRawValue: String
    var baseURLString: String
    var modelID: String
    var apiKey: String = ""
    var isDefault: Bool
    var supportsStreaming: Bool
    var timeoutSeconds: Double
    var maxOutputTokens: Int
    var temperature: Double
    var extraParametersJSON: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        kindRawValue: String,
        baseURLString: String,
        modelID: String,
        apiKey: String = "",
        isDefault: Bool = false,
        supportsStreaming: Bool = false,
        timeoutSeconds: Double = 60,
        maxOutputTokens: Int = 2048,
        temperature: Double = 0.2,
        extraParametersJSON: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.kindRawValue = kindRawValue
        self.baseURLString = baseURLString
        self.modelID = modelID
        self.apiKey = apiKey
        self.isDefault = isDefault
        self.supportsStreaming = supportsStreaming
        self.timeoutSeconds = timeoutSeconds
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.extraParametersJSON = extraParametersJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: AIProviderKind {
        AIProviderKind(rawValue: kindRawValue) ?? .openAICompatibleChat
    }

    var baseURL: URL? { URL(string: baseURLString) }

    var extraParameters: [String: Any]? {
        guard let json = extraParametersJSON, !json.isEmpty,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

struct AIProviderTemplate: Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let kind: AIProviderKind
    let baseURL: String
    let modelID: String
    let supportsStreaming: Bool?
    let note: String?
}
