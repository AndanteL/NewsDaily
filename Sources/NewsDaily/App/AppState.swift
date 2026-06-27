import Foundation
import SwiftUI
import SwiftData
import UserNotifications

enum SidebarSelection: Hashable, Sendable {
    case today
    case all
    case source(String)
    case favorites
    case readLater
    case vocabulary
}

@MainActor
final class AppState: ObservableObject {
    let persistence: PersistenceController
    let feedService: FeedService
    let translationService: TranslationService
    let settings: AppSettings
    let registry: SourceRegistry

    @Published var selectedSidebar: SidebarSelection = .today
    @Published var selectedArticleID: String?
    @Published var search: String = ""
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshSummary: FeedRefreshSummary?
    @Published var lastError: String?
    @Published var translationProgress: [String: TranslationProgress] = [:]
    @Published var pendingTranslationArticleIDs: Set<String> = []
    @Published var sourcesLastUpdated: [String: Date] = [:]

    init(
        persistence: PersistenceController = .shared,
        settings: AppSettings = AppSettings(),
        registry: SourceRegistry = SourceRegistry()
    ) {
        self.persistence = persistence
        self.settings = settings
        self.registry = registry
        self.feedService = FeedService(persistence: persistence)
        self.translationService = TranslationService(persistence: persistence, targetLanguage: settings.targetLanguage)
        ensureBuiltinSourcesLoaded()
        ensureDefaultProviderTemplates()
    }

    func bootstrap() async {
        if settings.autoRefreshOnLaunch {
            await refreshAll()
        }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let summary = await feedService.refreshAllSources()
        lastRefreshSummary = summary
        settings.lastRefreshDate = .now
        if summary.sourcesFailed > 0 && summary.sourcesSucceeded == 0 {
            lastError = "全部来源刷新失败"
        } else if summary.sourcesFailed > 0 {
            lastError = "\(summary.sourcesFailed) 个来源刷新失败"
        } else {
            lastError = nil
        }
        if settings.enableNotifications, summary.newArticles > 0 {
            await notifyNewArticles(count: summary.newArticles)
        }
        for source in persistence.fetchSources() {
            if let d = source.lastFetchedAt {
                sourcesLastUpdated[source.id] = d
            }
        }
    }

    func refresh(sourceID: String) async {
        guard let source = persistence.fetchSources().first(where: { $0.id == sourceID }) else { return }
        let result = await feedService.refresh(source: source)
        if let err = result.error {
            source.lastErrorMessage = err
        }
        persistence.save()
    }

    func ensureBuiltinSourcesLoaded() {
        guard let configs = try? registry.loadBuiltinSources() else { return }
        for config in configs {
            persistence.upsertSource(config: config)
        }
        persistence.save()
    }

    func ensureDefaultProviderTemplates() {
        let existing = persistence.fetchProviders()
        let existingProviderSignatures = Set(existing.map { "\($0.baseURLString)|\($0.modelID)" })
        let hasDefault = existing.contains(where: { $0.isDefault })
        guard let url = Bundle.main.url(forResource: "ai-providers", withExtension: "json")
            ?? Bundle.module.url(forResource: "ai-providers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let templates = try? JSONDecoder().decode([AIProviderTemplate].self, from: data) else {
            return
        }
        for template in templates {
            let signature = "\(template.baseURL)|\(template.modelID)"
            guard !existingProviderSignatures.contains(signature) else { continue }
            let config = AIProviderConfig(
                displayName: template.displayName,
                kindRawValue: template.kind.rawValue,
                baseURLString: template.baseURL,
                modelID: template.modelID,
                isDefault: template.id == "deepseek" && !hasDefault,
                supportsStreaming: template.supportsStreaming ?? false,
                maxOutputTokens: settings.maxOutputTokens,
                temperature: settings.translationTemperature
            )
            persistence.container.mainContext.insert(config)
        }
        persistence.save()
    }

    func toggleFavorite(_ article: Article) {
        article.isFavorite.toggle()
        persistence.save()
    }

    func toggleReadLater(_ article: Article) {
        article.readLater.toggle()
        persistence.save()
    }

    func markRead(_ article: Article) {
        if !article.isRead {
            article.isRead = true
            persistence.save()
        }
    }

    func deleteArticle(_ article: Article) {
        persistence.delete(article)
        persistence.save()
    }

    func articlesForCurrentSelection() -> [Article] {
        switch selectedSidebar {
        case .today:
            return persistence.fetchArticles(onlyToday: true, search: search.isEmpty ? nil : search)
        case .all:
            return persistence.fetchArticles(search: search.isEmpty ? nil : search)
        case .source(let id):
            return persistence.fetchArticles(sourceID: id, search: search.isEmpty ? nil : search)
        case .favorites:
            return persistence.fetchArticles(onlyFavorite: true, search: search.isEmpty ? nil : search)
        case .readLater:
            return persistence.fetchArticles(onlyReadLater: true, search: search.isEmpty ? nil : search)
        case .vocabulary:
            return []
        }
    }

    func requestTranslation(for article: Article) async {
        pendingTranslationArticleIDs.insert(article.id)
        translationProgress[article.id] = TranslationProgress(stage: .preparing, completed: 0, total: 1, message: nil)
        defer {
            pendingTranslationArticleIDs.remove(article.id)
            translationProgress[article.id] = nil
        }
        do {
            translationProgress[article.id] = TranslationProgress(stage: .translatingChunks, completed: 0, total: 1, message: nil)
            let translation = try await translationService.translateArticle(article, targetLanguage: settings.targetLanguage)
            translationProgress[article.id] = TranslationProgress(stage: .done, completed: 1, total: 1, message: nil)
            _ = translation
        } catch {
            translationProgress[article.id] = TranslationProgress(stage: .failed, completed: 0, total: 1, message: error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func cancelTranslation(articleID: String) {
        translationService.cancel(articleID: articleID)
        pendingTranslationArticleIDs.remove(articleID)
        translationProgress[articleID] = nil
    }

    func notifyNewArticles(count: Int) async {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            lastError = "通知不可用：当前未在 .app 包内运行"
            return
        }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge])) ?? false
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "NewsDaily"
        content.body = "新增 \(count) 条新闻"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "news-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        try? await center.add(req)
    }
}
