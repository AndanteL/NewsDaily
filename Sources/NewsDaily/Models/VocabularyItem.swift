import Foundation
import SwiftData

@Model
final class VocabularyItem {
    @Attribute(.unique) var id: String
    var text: String
    var sourceText: String
    var translation: String
    var explanation: String?
    var partOfSpeech: String?
    var example: String?
    var articleID: String?
    var articleTitle: String?
    var languageCode: String
    var createdAt: Date
    var reviewCount: Int
    var lastReviewedAt: Date?
    var isMastered: Bool

    init(
        id: String = UUID().uuidString,
        text: String,
        sourceText: String,
        translation: String,
        explanation: String? = nil,
        partOfSpeech: String? = nil,
        example: String? = nil,
        articleID: String? = nil,
        articleTitle: String? = nil,
        languageCode: String = "en",
        createdAt: Date = .now,
        reviewCount: Int = 0,
        lastReviewedAt: Date? = nil,
        isMastered: Bool = false
    ) {
        self.id = id
        self.text = text
        self.sourceText = sourceText
        self.translation = translation
        self.explanation = explanation
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.articleID = articleID
        self.articleTitle = articleTitle
        self.languageCode = languageCode
        self.createdAt = createdAt
        self.reviewCount = reviewCount
        self.lastReviewedAt = lastReviewedAt
        self.isMastered = isMastered
    }
}
