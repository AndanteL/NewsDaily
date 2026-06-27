import Foundation
import CryptoKit

struct TranslationCacheKey: Hashable, Sendable {
    let articleID: String
    let targetLanguage: String
    let model: String
    let contentHash: String
}

enum TranslationCache {
    static func key(articleID: String, targetLanguage: String, model: String, contentHash: String) -> TranslationCacheKey {
        TranslationCacheKey(articleID: articleID, targetLanguage: targetLanguage, model: model, contentHash: contentHash)
    }

    static func contentHash(title: String, summary: String?, body: String?) -> String {
        var combined = title
        if let s = summary { combined += "\n" + s }
        if let b = body { combined += "\n" + b }
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct TranslationProgress: Sendable, Hashable {
    enum Stage: String, Sendable, Hashable {
        case preparing
        case chunking
        case translatingChunks
        case merging
        case finalizing
        case done
        case failed
    }

    let stage: Stage
    let completed: Int
    let total: Int
    let message: String?
}
