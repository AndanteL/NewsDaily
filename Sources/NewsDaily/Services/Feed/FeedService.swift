import Foundation
import SwiftData

@MainActor
protocol FeedServiceProtocol {
    func refreshAllSources() async -> FeedRefreshSummary
    func refresh(source: NewsSource) async -> FeedSourceRefreshResult
}

struct FeedRefreshSummary: Sendable {
    var sourcesSucceeded: Int = 0
    var sourcesFailed: Int = 0
    var newArticles: Int = 0
    var totalArticles: Int = 0
    var failures: [FeedSourceRefreshResult] = []
    var startedAt: Date = .now
    var finishedAt: Date = .now

    var elapsed: TimeInterval { finishedAt.timeIntervalSince(startedAt) }
}

struct FeedSourceRefreshResult: Sendable {
    let sourceID: String
    let sourceName: String
    let newCount: Int
    let totalCount: Int
    let error: String?
}

@MainActor
final class FeedService: FeedServiceProtocol {
    let persistence: PersistenceController
    let parser: FeedParsing
    let session: URLSession
    let hotScoreService: HotScoreService
    let contentService: ArticleContentService

    init(
        persistence: PersistenceController = .shared,
        parser: FeedParsing = FeedParser(),
        session: URLSession = FeedService.defaultSession(),
        hotScoreService: HotScoreService = HotScoreService(),
        contentService: ArticleContentService = ArticleContentService()
    ) {
        self.persistence = persistence
        self.parser = parser
        self.session = session
        self.hotScoreService = hotScoreService
        self.contentService = contentService
    }

    static func defaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024)
        return URLSession(configuration: config)
    }

    func refreshAllSources() async -> FeedRefreshSummary {
        var summary = FeedRefreshSummary()
        summary.startedAt = .now
        let sources = persistence.fetchSources(enabledOnly: true)
        await withTaskGroup(of: FeedSourceRefreshResult.self) { group in
            for source in sources {
                let snapshot = SourceSnapshot(source: source)
                group.addTask { [weak self] in
                    guard let self else { return FeedSourceRefreshResult(sourceID: snapshot.id, sourceName: snapshot.name, newCount: 0, totalCount: 0, error: "service released") }
                    return await self.refresh(snapshot: snapshot)
                }
            }
            for await result in group {
                if result.error == nil {
                    summary.sourcesSucceeded += 1
                    summary.newArticles += result.newCount
                    summary.totalArticles += result.totalCount
                } else {
                    summary.sourcesFailed += 1
                    summary.failures.append(result)
                }
            }
        }
        summary.finishedAt = .now
        return summary
    }

    func refresh(source: NewsSource) async -> FeedSourceRefreshResult {
        let snapshot = SourceSnapshot(source: source)
        return await refresh(snapshot: snapshot)
    }

    private func refresh(snapshot: SourceSnapshot) async -> FeedSourceRefreshResult {
        guard let feedURL = snapshot.feedURL else {
            return FeedSourceRefreshResult(sourceID: snapshot.id, sourceName: snapshot.name, newCount: 0, totalCount: 0, error: "未配置 RSS feed URL")
        }

        var request = URLRequest(url: feedURL)
        request.setValue("NewsDaily/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return FeedSourceRefreshResult(sourceID: snapshot.id, sourceName: snapshot.name, newCount: 0, totalCount: 0, error: "HTTP \(http.statusCode)")
            }
            let tempSource = NewsSource.fromConfig(NewsSourceConfig(id: snapshot.id, name: snapshot.name, homepage: snapshot.homepageURLString, feedURL: snapshot.feedURLString, language: snapshot.languageCode, region: snapshot.region, enabled: true))
            let drafts = try parser.parse(data: data, source: tempSource)
            return await persist(drafts: drafts, snapshot: snapshot)
        } catch {
            return FeedSourceRefreshResult(sourceID: snapshot.id, sourceName: snapshot.name, newCount: 0, totalCount: 0, error: error.localizedDescription)
        }
    }

    private func persist(drafts: [ArticleDraft], snapshot: SourceSnapshot) async -> FeedSourceRefreshResult {
        let context = persistence.container.mainContext
        var newCount = 0
        var totalCount = 0

        let sourceIDForPredicate = snapshot.id
        let existingURLs: Set<String> = {
            let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.sourceID == sourceIDForPredicate })
            let articles = (try? context.fetch(descriptor)) ?? []
            return Set(articles.map { ArticleNormalizer.canonicalURL($0.urlString) })
        }()
        let existingGUIDs: Set<String> = {
            let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.sourceID == sourceIDForPredicate })
            let articles = (try? context.fetch(descriptor)) ?? []
            return Set(articles.compactMap { $0.guid })
        }()

        for draft in drafts {
            let canonical = ArticleNormalizer.canonicalURL(draft.urlString)
            let guid = draft.guid
            let dupByURL = existingURLs.contains(canonical)
            let dupByGUID = guid.map { existingGUIDs.contains($0) } ?? false
            if dupByURL || dupByGUID { continue }

            let articleID = ArticleNormalizer.articleID(sourceID: draft.sourceID, urlString: draft.urlString, guid: guid)
            let keywords = HotScoreService.extractKeywords(from: draft.title, summary: draft.summary)
            let fullContent = await fetchFullContentIfAvailable(urlString: draft.urlString)
            let imageURLs = mergeImageURLs(primary: draft.imageURLString, extracted: fullContent?.imageURLStrings ?? [])
            let article = Article(
                id: articleID,
                sourceID: draft.sourceID,
                title: draft.title,
                summary: draft.summary,
                urlString: draft.urlString,
                publishedAt: draft.publishedAt,
                fetchedAt: .now,
                author: draft.author ?? fullContent?.author,
                imageURLString: imageURLs.first ?? draft.imageURLString,
                bodyText: fullContent?.bodyText,
                imageURLsString: imageURLs.joined(separator: "\n"),
                languageCode: draft.languageCode,
                guid: guid,
                contentHash: ArticleNormalizer.contentHash(title: draft.title, summary: draft.summary)
            )
            article.setKeywords(keywords)
            article.hotScore = hotScoreService.compute(
                publishedAt: draft.publishedAt,
                sourceWeight: snapshot.weight,
                keywords: keywords,
                duplicatesInOtherSources: 0
            )
            context.insert(article)
            newCount += 1
            totalCount += 1
        }

        // Update source.lastFetchedAt and clear prior error.
        if let source = persistence.fetchSources().first(where: { $0.id == snapshot.id }) {
            source.lastFetchedAt = .now
            source.lastErrorMessage = nil
        }
        persistence.save()
        return FeedSourceRefreshResult(sourceID: snapshot.id, sourceName: snapshot.name, newCount: newCount, totalCount: totalCount, error: nil)
    }

    private func fetchFullContentIfAvailable(urlString: String) async -> ArticleFullContent? {
        guard let url = URL(string: urlString) else { return nil }
        return try? await contentService.fetchContent(url: url)
    }

    private func mergeImageURLs(primary: String?, extracted: [String]) -> [String] {
        var values = extracted
        if let primary, !primary.isEmpty {
            values.insert(primary, at: 0)
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

struct SourceSnapshot: Sendable {
    let id: String
    let name: String
    let homepageURLString: String
    let feedURLString: String?
    let languageCode: String
    let region: String
    let weight: Double

    init(source: NewsSource) {
        self.id = source.id
        self.name = source.name
        self.homepageURLString = source.homepageURLString
        self.feedURLString = source.feedURLString
        self.languageCode = source.languageCode
        self.region = source.region
        self.weight = source.weight
    }

    var feedURL: URL? {
        guard let s = feedURLString, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var feedURLStringSafe: String { feedURLString ?? "" }
}
