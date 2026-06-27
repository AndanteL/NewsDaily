import Foundation

struct ArticleFullContent: Sendable {
    let bodyText: String?
    let imageURLStrings: [String]
    let author: String?
}

final class ArticleContentService: @unchecked Sendable {
    let session: URLSession

    init(session: URLSession = ArticleContentService.defaultSession()) {
        self.session = session
    }

    static func defaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024)
        return URLSession(configuration: config)
    }

    func fetchContent(url: URL) async throws -> ArticleFullContent {
        var request = URLRequest(url: url)
        request.setValue("NewsDaily/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }

        let extracted = ContentExtractor.extract(from: html, baseURL: url)
        let bodyText = extracted.paragraphs.isEmpty ? nil : extracted.paragraphs.joined(separator: "\n\n")
        return ArticleFullContent(
            bodyText: bodyText,
            imageURLStrings: extracted.imageURLs,
            author: extracted.byline
        )
    }
}
