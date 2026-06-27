import Foundation
import SwiftData

@Model
final class NewsSource {
    @Attribute(.unique) var id: String
    var name: String
    var homepageURLString: String
    var feedURLString: String?
    var languageCode: String
    var region: String
    var isEnabled: Bool
    var weight: Double
    var lastFetchedAt: Date?
    var lastErrorMessage: String?
    var note: String?

    init(
        id: String,
        name: String,
        homepageURLString: String,
        feedURLString: String? = nil,
        languageCode: String,
        region: String,
        isEnabled: Bool = true,
        weight: Double = 1.0,
        lastFetchedAt: Date? = nil,
        lastErrorMessage: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.homepageURLString = homepageURLString
        self.feedURLString = feedURLString
        self.languageCode = languageCode
        self.region = region
        self.isEnabled = isEnabled
        self.weight = weight
        self.lastFetchedAt = lastFetchedAt
        self.lastErrorMessage = lastErrorMessage
        self.note = note
    }

    var homepageURL: URL? { URL(string: homepageURLString) }
    var feedURL: URL? {
        guard let s = feedURLString, !s.isEmpty else { return nil }
        return URL(string: s)
    }
}

struct NewsSourceConfig: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let homepage: String
    let feedURL: String?
    let language: String
    let region: String
    var enabled: Bool
    var weight: Double?
    let note: String?

    init(
        id: String,
        name: String,
        homepage: String,
        feedURL: String?,
        language: String,
        region: String,
        enabled: Bool = true,
        weight: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.homepage = homepage
        self.feedURL = feedURL
        self.language = language
        self.region = region
        self.enabled = enabled
        self.weight = weight
        self.note = note
    }
}

extension NewsSource {
    func applyConfig(_ config: NewsSourceConfig) {
        self.name = config.name
        self.homepageURLString = config.homepage
        self.feedURLString = config.feedURL
        self.languageCode = config.language
        self.region = config.region
        self.isEnabled = config.enabled
        if let w = config.weight { self.weight = w }
        self.note = config.note
    }

    static func fromConfig(_ config: NewsSourceConfig) -> NewsSource {
        NewsSource(
            id: config.id,
            name: config.name,
            homepageURLString: config.homepage,
            feedURLString: config.feedURL,
            languageCode: config.language,
            region: config.region,
            isEnabled: config.enabled,
            weight: config.weight ?? 1.0,
            note: config.note
        )
    }
}
