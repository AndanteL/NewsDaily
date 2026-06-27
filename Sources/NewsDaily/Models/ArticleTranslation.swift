import Foundation
import SwiftData

@Model
final class ArticleTranslation {
    @Attribute(.unique) var id: String
    var articleID: String
    var sourceLanguage: String
    var targetLanguage: String
    var translatedTitle: String
    var translatedSummary: String?
    var translatedBody: String?
    var paragraphsJSON: String?
    var keyTermsJSON: String?
    var model: String
    var providerID: String
    var contentHash: String?
    var createdAt: Date
    var statusRawValue: String
    var errorMessage: String?

    init(
        id: String = UUID().uuidString,
        articleID: String,
        sourceLanguage: String,
        targetLanguage: String,
        translatedTitle: String,
        translatedSummary: String? = nil,
        translatedBody: String? = nil,
        paragraphsJSON: String? = nil,
        keyTermsJSON: String? = nil,
        model: String,
        providerID: String,
        contentHash: String? = nil,
        createdAt: Date = .now,
        statusRawValue: String = TranslationStatus.completed.rawValue,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.articleID = articleID
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translatedTitle = translatedTitle
        self.translatedSummary = translatedSummary
        self.translatedBody = translatedBody
        self.paragraphsJSON = paragraphsJSON
        self.keyTermsJSON = keyTermsJSON
        self.model = model
        self.providerID = providerID
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.statusRawValue = statusRawValue
        self.errorMessage = errorMessage
    }

    var status: TranslationStatus {
        TranslationStatus(rawValue: statusRawValue) ?? .failed
    }

    var paragraphs: [TranslatedParagraph] {
        guard let json = paragraphsJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([TranslatedParagraph].self, from: data)) ?? []
    }

    var keyTerms: [KeyTerm] {
        guard let json = keyTermsJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([KeyTerm].self, from: data)) ?? []
    }
}

enum TranslationStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

struct TranslatedParagraph: Codable, Hashable, Sendable {
    let index: Int
    let source: String
    let translation: String
}

struct KeyTerm: Codable, Hashable, Sendable {
    let term: String
    let translation: String
    let explanation: String?
}

struct SelectionTranslation: Codable, Hashable, Sendable {
    let translation: String
    let partOfSpeech: String?
    let explanation: String?
    let example: String?
    let confidence: Double
}
