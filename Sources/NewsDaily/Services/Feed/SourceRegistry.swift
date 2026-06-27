import Foundation

protocol SourceRegistryProtocol {
    func loadBuiltinSources() throws -> [NewsSourceConfig]
    func loadRemoteSources(from url: URL) async throws -> [NewsSourceConfig]
    func discoverFeedURL(from homepageURL: URL) async throws -> URL?
}

enum SourceRegistryError: LocalizedError {
    case bundledNotFound
    case decodeFailed(String)
    case discoveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledNotFound: return "找不到内置 sources.json"
        case .decodeFailed(let s): return "解析 sources 失败: \(s)"
        case .discoveryFailed(let s): return "RSS 自动发现失败: \(s)"
        }
    }
}

struct SourceRegistry: SourceRegistryProtocol {
    let parser: FeedParsing
    let session: URLSession
    let bundledURL: URL?

    init(parser: FeedParsing = FeedParser(), session: URLSession = .shared, bundledURL: URL? = nil) {
        self.parser = parser
        self.session = session
        self.bundledURL = bundledURL ?? SourceRegistry.defaultBundledURL()
    }

    static func defaultBundledURL() -> URL? {
        Bundle.main.url(forResource: "sources", withExtension: "json")
        ?? Bundle.module.url(forResource: "sources", withExtension: "json")
    }

    func loadBuiltinSources() throws -> [NewsSourceConfig] {
        guard let url = bundledURL, let data = try? Data(contentsOf: url) else {
            throw SourceRegistryError.bundledNotFound
        }
        do {
            return try JSONDecoder().decode([NewsSourceConfig].self, from: data)
        } catch {
            throw SourceRegistryError.decodeFailed(error.localizedDescription)
        }
    }

    func loadRemoteSources(from url: URL) async throws -> [NewsSourceConfig] {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceRegistryError.decodeFailed("HTTP \(http.statusCode)")
        }
        do {
            return try JSONDecoder().decode([NewsSourceConfig].self, from: data)
        } catch {
            throw SourceRegistryError.decodeFailed(error.localizedDescription)
        }
    }

    func discoverFeedURL(from homepageURL: URL) async throws -> URL? {
        var req = URLRequest(url: homepageURL)
        req.setValue("NewsDaily/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceRegistryError.discoveryFailed("HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw SourceRegistryError.discoveryFailed("非 UTF-8 HTML")
        }
        return Self.extractFeedLink(from: html, baseURL: homepageURL)
    }

    static func extractFeedLink(from html: String, baseURL: URL) -> URL? {
        let pattern = #"<link[^>]*type=["']application/(rss|atom)\+xml["'][^>]*href=["']([^"']+)["'][^>]*/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           match.numberOfRanges >= 3 {
            let href = ns.substring(with: match.range(at: 2))
            if let u = URL(string: href, relativeTo: baseURL) {
                return u.absoluteURL
            }
        }
        // Try alternate attribute order: href before type
        let altPattern = #"<link[^>]*href=["']([^"']+)["'][^>]*type=["']application/(rss|atom)\+xml["'][^>]*/?>"#
        if let altRegex = try? NSRegularExpression(pattern: altPattern, options: [.caseInsensitive]),
           let altMatch = altRegex.firstMatch(in: html, options: [], range: range),
           altMatch.numberOfRanges >= 2 {
            let href = ns.substring(with: altMatch.range(at: 1))
            if let u = URL(string: href, relativeTo: baseURL) {
                return u.absoluteURL
            }
        }
        return nil
    }
}
