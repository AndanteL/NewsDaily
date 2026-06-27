import Foundation

struct ExtractedContent: Hashable, Sendable {
    let title: String?
    let paragraphs: [String]
    let imageURLs: [String]
    let byline: String?
    let excerpt: String?
}

enum ContentExtractor {
    static func extract(from html: String, baseURL: URL? = nil) -> ExtractedContent {
        let paragraphs = extractParagraphs(html: html)
        let imageURLs = extractImageURLs(html: html, baseURL: baseURL)
        let title = extractTitle(html: html)
        let byline = extractMetaContent(html: html, name: "author")
        let excerpt = extractMetaContent(html: html, name: "description")
        return ExtractedContent(
            title: title,
            paragraphs: paragraphs,
            imageURLs: imageURLs,
            byline: byline,
            excerpt: excerpt
        )
    }

    static func extractTitle(html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let m = regex.firstMatch(in: html, options: [], range: range), m.numberOfRanges >= 2 {
            return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let ogPattern = #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#
        if let ogRegex = try? NSRegularExpression(pattern: ogPattern, options: [.caseInsensitive]),
           let ogMatch = ogRegex.firstMatch(in: html, options: [], range: range),
           ogMatch.numberOfRanges >= 2 {
            return ns.substring(with: ogMatch.range(at: 1))
        }
        return nil
    }

    static func extractMetaContent(html: String, name: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            "<meta[^>]+name=[\"']\(escaped)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+name=[\"']\(escaped)[\"']",
            "<meta[^>]+property=[\"']\(escaped)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        ]
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]),
               let m = regex.firstMatch(in: html, options: [], range: range),
               m.numberOfRanges >= 2 {
                return ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func extractParagraphs(html: String) -> [String] {
        let scopedHTML = preferredContentHTML(from: removeNonContentBlocks(from: html))
        let blockParagraphs = extractTextBlocks(from: scopedHTML)
        if !blockParagraphs.isEmpty {
            return sanitizeParagraphs(blockParagraphs)
        }
        let cleaned = stripTags(html: scopedHTML)
        return sanitizeParagraphs(cleaned
            .components(separatedBy: "\n\n")
        )
    }

    static func sanitizeParagraphs(_ paragraphs: [String]) -> [String] {
        paragraphs
            .map(cleanParagraph)
            .filter { paragraph in
                guard paragraph.count >= 40 || (paragraph.contains(".") && paragraph.count >= 20) else { return false }
                return !containsBoilerplateNoise(paragraph)
            }
    }

    static func containsBoilerplateNoise(_ text: String) -> Bool {
        let compact = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .lowercased()
        let hardMarkers = [
            "homepageskiptocontent",
            "accessibilityhelpyouraccount",
            "morenumoremenusearch",
            "moremenusearch",
            "closemenubbcnews",
            "homenewssportearthreel",
            "bbchomenewssport",
            "youraccounthomenews",
            "skiptoaccessibilityhelp"
        ]
        if hardMarkers.contains(where: { compact.contains($0) }) {
            return true
        }
        let lower = text.lowercased()
        if lower.hasPrefix("image source") || lower.hasPrefix("image caption") {
            return true
        }
        let navTerms = ["home", "news", "sport", "earth", "reel", "worklife", "travel", "culture", "future", "music", "tv", "weather", "sounds", "search"]
        let matches = navTerms.reduce(0) { count, term in
            compact.contains(term) ? count + 1 : count
        }
        return matches >= 8 && compact.count < 800
    }

    static func extractImageURLs(html: String, baseURL: URL? = nil) -> [String] {
        var candidates: [String] = []
        let metaNames = ["og:image", "twitter:image", "twitter:image:src"]
        for name in metaNames {
            if let value = extractMetaContent(html: html, name: name) {
                candidates.append(value)
            }
        }

        let imgPattern = #"<img\b[^>]*(?:src|data-src)=["']([^"']+)["'][^>]*>"#
        appendMatches(pattern: imgPattern, in: html, to: &candidates)

        let srcsetPattern = #"(?:srcset|data-srcset)=["']([^"']+)["']"#
        let srcsets = matches(pattern: srcsetPattern, in: html)
        for srcset in srcsets {
            if let first = srcset
                .split(separator: ",")
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first?
                .split(separator: " ")
                .first {
                candidates.append(String(first))
            }
        }

        var seen = Set<String>()
        return candidates.compactMap { raw in
            let trimmed = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("data:"),
                  !trimmed.hasSuffix(".svg") else { return nil }
            let absolute = resolveURL(trimmed, baseURL: baseURL)
            guard let absolute, seen.insert(absolute).inserted else { return nil }
            return absolute
        }
    }

    private static func appendMatches(pattern: String, in html: String, to candidates: inout [String]) {
        candidates.append(contentsOf: matches(pattern: pattern, in: html))
    }

    private static func matches(pattern: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    private static func preferredContentHTML(from html: String) -> String {
        if let article = firstTagContent("article", in: html) {
            return article
        }
        if let main = firstTagContent("main", in: html) {
            return main
        }
        if let body = firstTagContent("body", in: html) {
            return body
        }
        return html
    }

    private static func firstTagContent(_ tag: String, in html: String) -> String? {
        let pattern = #"<"# + tag + #"\b[^>]*>([\s\S]*?)</"# + tag + #">"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges >= 2 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private static func removeNonContentBlocks(from html: String) -> String {
        var s = html
        let tagNames = ["script", "style", "noscript", "svg", "header", "nav", "footer", "aside", "form", "button", "dialog"]
        for tag in tagNames {
            s = s.replacingOccurrences(of: "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        let noisyAttributePattern = #"<([a-zA-Z0-9]+)\b[^>]*(?:class|id)=["'][^"']*(?:nav|menu|header|footer|skip|accessibility|promo|advert|cookie|share|related|newsletter|signin|account)[^"']*["'][^>]*>[\s\S]*?</\1>"#
        s = s.replacingOccurrences(of: noisyAttributePattern, with: "", options: [.regularExpression, .caseInsensitive])
        return s
    }

    private static func extractTextBlocks(from html: String) -> [String] {
        let pattern = #"<(?:p|h2|h3)\b[^>]*>([\s\S]*?)</(?:p|h2|h3)>"#
        return matches(pattern: pattern, in: html)
    }

    private static func cleanParagraph(_ raw: String) -> String {
        var text = stripTags(html: raw)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"^\s*(Image source|Image caption),?\s*[^.。]*[.。]?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveURL(_ value: String, baseURL: URL?) -> String? {
        if value.hasPrefix("//") {
            return "https:\(value)"
        }
        if let url = URL(string: value), url.scheme != nil {
            return url.absoluteString
        }
        guard let baseURL else { return nil }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL.absoluteString
    }

    static func stripTags(html: String) -> String {
        var s = html
        // Remove scripts and styles entirely
        s = s.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<noscript[^>]*>[\s\S]*?</noscript>"#, with: "", options: .regularExpression)
        // Convert common block boundaries to newlines before stripping the rest.
        s = s.replacingOccurrences(of: #"</p>"#, with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"</h[1-6]>"#, with: "\n\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"</li>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"</div>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        // Strip the rest of tags
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        // Decode common entities
        s = decodeEntities(s)
        return s
    }

    static func decodeEntities(_ string: String) -> String {
        var s = string
        let map: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&mdash;", "\u{2014}"), ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}")
        ]
        for (e, c) in map {
            s = s.replacingOccurrences(of: e, with: c)
        }
        // Numeric decimal and hex entities.
        let pattern = #"&#(?:x([0-9A-Fa-f]+)|(\d+));"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = s as NSString
            var result = ""
            var lastEnd = 0
            let range = NSRange(location: 0, length: ns.length)
            regex.enumerateMatches(in: s, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges >= 3 else { return }
                result.append(ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd)))
                let hexRange = match.range(at: 1)
                let decimalRange = match.range(at: 2)
                let code: UInt32?
                if hexRange.location != NSNotFound {
                    code = UInt32(ns.substring(with: hexRange), radix: 16)
                } else if decimalRange.location != NSNotFound {
                    code = UInt32(ns.substring(with: decimalRange), radix: 10)
                } else {
                    code = nil
                }
                if let code, let scalar = Unicode.Scalar(code) {
                    result.append(Character(scalar))
                }
                lastEnd = match.range.location + match.range.length
            }
            if lastEnd < ns.length {
                result.append(ns.substring(from: lastEnd))
            }
            s = result
        }
        return s
    }
}
