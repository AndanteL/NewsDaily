import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init(inMemory: Bool = false) {
        let schema = Schema([
            NewsSource.self,
            Article.self,
            ArticleTranslation.self,
            VocabularyItem.self,
            AIProviderConfig.self
        ])

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let url = PersistenceController.defaultStoreURL
            config = ModelConfiguration(schema: schema, url: url)
        }

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            if !inMemory, let url = PersistenceController.defaultStoreURLFile {
                try? FileManager.default.removeItem(at: url)
                if let recovered = try? ModelContainer(for: schema, configurations: [config]) {
                    container = recovered
                    return
                }
            }
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Unable to create ModelContainer: \(error)")
            }
        }
    }

    static var defaultStoreURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? URL.temporaryDirectory
        let folder = appSupport.appendingPathComponent("NewsDaily", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("NewsDaily.store")
    }

    static var defaultStoreURLFile: URL? {
        let url = defaultStoreURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
            return url
        }
        return nil
    }

    @discardableResult
    func upsertSource(config: NewsSourceConfig) -> NewsSource? {
        let context = container.mainContext
        let id = config.id
        let descriptor = FetchDescriptor<NewsSource>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.applyConfig(config)
            return existing
        }
        let source = NewsSource.fromConfig(config)
        context.insert(source)
        return source
    }

    func fetchSources(enabledOnly: Bool = false) -> [NewsSource] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<NewsSource>(sortBy: [SortDescriptor(\.name)])
        if enabledOnly {
            descriptor.predicate = #Predicate { $0.isEnabled }
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchArticles(
        sourceID: String? = nil,
        onlyFavorite: Bool = false,
        onlyReadLater: Bool = false,
        onlyToday: Bool = false,
        search: String? = nil,
        limit: Int = 500
    ) -> [Article] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.hotScore, order: .reverse), SortDescriptor(\.publishedAt, order: .reverse)]
        )
        let raw = (try? context.fetch(descriptor)) ?? []

        let startOfDay = Calendar.current.startOfDay(for: .now)
        let q = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = raw.filter { article in
            if let sourceID, article.sourceID != sourceID { return false }
            if onlyFavorite && !article.isFavorite { return false }
            if onlyReadLater && !article.readLater { return false }
            if onlyToday {
                let date = article.publishedAt ?? article.fetchedAt
                if date < startOfDay { return false }
            }
            if let q, !q.isEmpty {
                let title = article.title.lowercased()
                let summary = (article.summary ?? "").lowercased()
                if !title.contains(q) && !summary.contains(q) { return false }
            }
            return true
        }
        return Array(filtered.prefix(limit))
    }

    func fetchArticle(id: String) -> Article? {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func fetchTranslation(articleID: String, targetLanguage: String, model: String) -> ArticleTranslation? {
        let context = container.mainContext
        let descriptor = FetchDescriptor<ArticleTranslation>(
            predicate: #Predicate {
                $0.articleID == articleID && $0.targetLanguage == targetLanguage && $0.model == model
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    func fetchVocabulary(search: String? = nil, includeMastered: Bool = true) -> [VocabularyItem] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<VocabularyItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let raw = (try? context.fetch(descriptor)) ?? []
        let q = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return raw.filter { item in
            if !includeMastered && item.isMastered { return false }
            if let q, !q.isEmpty {
                let t = item.text.lowercased()
                let tr = item.translation.lowercased()
                if !t.contains(q) && !tr.contains(q) { return false }
            }
            return true
        }
    }

    func fetchProviders() -> [AIProviderConfig] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<AIProviderConfig>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func defaultProvider() -> AIProviderConfig? {
        let context = container.mainContext
        let descriptor = FetchDescriptor<AIProviderConfig>(predicate: #Predicate { $0.isDefault })
        if let p = try? context.fetch(descriptor).first { return p }
        return fetchProviders().first
    }

    func save() {
        let context = container.mainContext
        try? context.save()
    }

    func delete<T: PersistentModel>(_ object: T) {
        container.mainContext.delete(object)
    }
}
