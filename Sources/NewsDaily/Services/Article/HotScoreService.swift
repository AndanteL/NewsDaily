import Foundation

struct HotScoreService {
    static let defaultHotKeywords: [String: Double] = [
        "politics": 1.0,
        "election": 1.0,
        "war": 1.2,
        "ukraine": 1.1,
        "gaza": 1.1,
        "israel": 0.9,
        "economy": 0.9,
        "market": 0.8,
        "ai": 1.0,
        "openai": 1.0,
        "gpt": 0.9,
        "apple": 0.7,
        "google": 0.7,
        "microsoft": 0.7,
        "tesla": 0.7,
        "fed": 0.9,
        "rate": 0.7,
        "inflation": 0.8,
        "climate": 0.8,
        "covid": 0.8,
        "trump": 0.9,
        "biden": 0.8,
        "china": 0.7,
        "nato": 0.9,
        "breaking": 0.7
    ]

    let recencyWeightValue: Double
    let sourceWeightValue: Double
    let keywordWeightValue: Double
    let duplicateTopicWeightValue: Double
    let now: Date

    init(
        recencyWeight: Double = 0.45,
        sourceWeight: Double = 0.20,
        keywordWeight: Double = 0.20,
        duplicateTopicWeight: Double = 0.15,
        now: Date = .now
    ) {
        self.recencyWeightValue = recencyWeight
        self.sourceWeightValue = sourceWeight
        self.keywordWeightValue = keywordWeight
        self.duplicateTopicWeightValue = duplicateTopicWeight
        self.now = now
    }

    func compute(
        publishedAt: Date?,
        sourceWeight: Double,
        keywords: [String],
        duplicatesInOtherSources: Int
    ) -> Double {
        let recency = recencyScore(publishedAt: publishedAt)
        let source = min(max(sourceWeight, 0), 2.0) / 2.0
        let keyword = keywordScore(keywords: keywords)
        let duplicate = duplicateTopicScore(count: duplicatesInOtherSources)
        return recency * recencyWeightValue
            + source * sourceWeightValue
            + keyword * keywordWeightValue
            + duplicate * duplicateTopicWeightValue
    }

    func recencyScore(publishedAt: Date?) -> Double {
        let date = publishedAt ?? now
        let hoursAgo = max(0, now.timeIntervalSince(date) / 3600.0)
        let score = exp(-hoursAgo / 24.0)
        return min(max(score, 0), 1)
    }

    func keywordScore(keywords: [String]) -> Double {
        guard !keywords.isEmpty else { return 0 }
        var total = 0.0
        for kw in keywords {
            total += Self.defaultHotKeywords[kw.lowercased()] ?? 0
        }
        return min(total / max(Double(keywords.count), 1), 1.0)
    }

    func duplicateTopicScore(count: Int) -> Double {
        switch count {
        case 0: return 0
        case 1: return 0.4
        case 2: return 0.7
        default: return 1.0
        }
    }

    static func extractKeywords(from title: String, summary: String?) -> [String] {
        let combined = (title + " " + (summary ?? "")).lowercased()
        var found: [String] = []
        let seen = NSMutableSet()
        for kw in defaultHotKeywords.keys {
            if combined.contains(kw), !seen.contains(kw) {
                found.append(kw)
                seen.add(kw)
            }
        }
        return found
    }
}
