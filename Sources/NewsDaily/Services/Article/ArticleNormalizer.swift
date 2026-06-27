import Foundation
import CryptoKit

enum ArticleNormalizer {
    static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "mc_cid", "mc_eid", "ref", "ref_src", "ref_url",
        "_ga", "_gl", "igshid", "spm", "ns_source", "ns_mchannel", "ns_campaign"
    ]

    static func canonicalURL(_ raw: String) -> String {
        guard let url = URL(string: raw) else {
            return raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let host = components?.host { components?.host = host.lowercased() }
        components?.fragment = nil
        if let items = components?.queryItems {
            let filtered = items.filter { item in
                !trackingParams.contains(item.name.lowercased())
            }
            components?.queryItems = filtered.isEmpty ? nil : filtered
        }
        var result = components?.url?.absoluteString ?? raw
        while result.hasSuffix("/") { result.removeLast() }
        return result
    }

    static func articleID(sourceID: String, urlString: String, guid: String?) -> String {
        if let guid, !guid.isEmpty { return "\(sourceID):\(guid)" }
        return "\(sourceID):\(canonicalURL(urlString))"
    }

    static func contentHash(title: String, summary: String?) -> String {
        let combined = (title + "\n" + (summary ?? ""))
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        let aTokens = Set(Self.tokenize(a))
        let bTokens = Set(Self.tokenize(b))
        guard !aTokens.isEmpty, !bTokens.isEmpty else { return 0 }
        let inter = aTokens.intersection(bTokens).count
        return Double(inter) / Double(max(aTokens.count, bTokens.count))
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { $0.count > 2 }
            .map { String($0) }
    }
}
