import Foundation
import SwiftData

@Model
final class Article {
    @Attribute(.unique) var id: String
    var sourceID: String
    var title: String
    var summary: String?
    var urlString: String
    var publishedAt: Date?
    var fetchedAt: Date
    var author: String?
    var imageURLString: String?
    var bodyText: String?
    var imageURLsString: String?
    var languageCode: String
    var isRead: Bool
    var isFavorite: Bool
    var readLater: Bool
    var hotScore: Double
    var guid: String?
    var contentHash: String?
    var keywordsString: String?

    init(
        id: String,
        sourceID: String,
        title: String,
        summary: String? = nil,
        urlString: String,
        publishedAt: Date? = nil,
        fetchedAt: Date = .now,
        author: String? = nil,
        imageURLString: String? = nil,
        bodyText: String? = nil,
        imageURLsString: String? = nil,
        languageCode: String,
        isRead: Bool = false,
        isFavorite: Bool = false,
        readLater: Bool = false,
        hotScore: Double = 0,
        guid: String? = nil,
        contentHash: String? = nil,
        keywordsString: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.summary = summary
        self.urlString = urlString
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
        self.author = author
        self.imageURLString = imageURLString
        self.bodyText = bodyText
        self.imageURLsString = imageURLsString
        self.languageCode = languageCode
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.readLater = readLater
        self.hotScore = hotScore
        self.guid = guid
        self.contentHash = contentHash
        self.keywordsString = keywordsString
    }

    var url: URL? { URL(string: urlString) }
    var imageURL: URL? {
        guard let s = imageURLString, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    var imageURLs: [URL] {
        var strings: [String] = []
        if let imageURLString, !imageURLString.isEmpty {
            strings.append(imageURLString)
        }
        if let imageURLsString, !imageURLsString.isEmpty {
            strings.append(contentsOf: imageURLsString
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            )
        }
        var seen = Set<String>()
        return strings.compactMap { value in
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            return URL(string: value)
        }
    }
    var keywords: [String] {
        guard let s = keywordsString, !s.isEmpty else { return [] }
        return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    var bodyParagraphs: [String] {
        guard let bodyText, !bodyText.isEmpty else { return [] }
        return bodyText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func setKeywords(_ kws: [String]) {
        keywordsString = kws.joined(separator: ",")
    }
}

struct ArticleDraft: Hashable, Sendable {
    let sourceID: String
    let title: String
    let summary: String?
    let urlString: String
    let publishedAt: Date?
    let author: String?
    let imageURLString: String?
    let languageCode: String
    let guid: String?

    init(
        sourceID: String,
        title: String,
        summary: String? = nil,
        urlString: String,
        publishedAt: Date? = nil,
        author: String? = nil,
        imageURLString: String? = nil,
        languageCode: String,
        guid: String? = nil
    ) {
        self.sourceID = sourceID
        self.title = title
        self.summary = summary
        self.urlString = urlString
        self.publishedAt = publishedAt
        self.author = author
        self.imageURLString = imageURLString
        self.languageCode = languageCode
        self.guid = guid
    }
}
