import Foundation
import SwiftData

@MainActor
protocol TranslationServiceProtocol {
    func translateArticle(_ article: Article, targetLanguage: String?) async throws -> ArticleTranslation
    func translateSelection(text: String, context: String, targetLanguage: String) async throws -> SelectionTranslation
    func cancel(articleID: String)
}

@MainActor
final class TranslationService: TranslationServiceProtocol {
    let persistence: PersistenceController
    let factory: AIProviderClientFactory
    let session: URLSession
    let contentService: ArticleContentService
    let targetLanguage: String

    private var cancellables: [String: Task<Void, Error>] = [:]

    init(
        persistence: PersistenceController = .shared,
        factory: AIProviderClientFactory = AIProviderClientFactory(),
        session: URLSession = .shared,
        contentService: ArticleContentService = ArticleContentService(),
        targetLanguage: String = "zh-Hans"
    ) {
        self.persistence = persistence
        self.factory = factory
        self.session = session
        self.contentService = contentService
        self.targetLanguage = targetLanguage
    }

    func translateArticle(_ article: Article, targetLanguage: String? = nil) async throws -> ArticleTranslation {
        let lang = targetLanguage ?? self.targetLanguage
        await ensureFullContentIfNeeded(for: article)
        if let existing = findCachedTranslation(for: article, targetLanguage: lang) {
            return existing
        }
        let provider = persistence.defaultProvider()
        guard let provider else { throw AIProviderError.invalidConfig("未配置 AI Provider，请在设置中添加") }
        let apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtimeConfig = ProviderRuntimeConfig(provider).disablingReasoningForTranslation()
        let client = factory.makeClient(for: runtimeConfig.kind)
        let providerID = provider.id
        let modelID = provider.modelID

        let task = Task { [weak self] in
            guard let self else { return }
            _ = try await self.runTranslation(
                article: article,
                runtimeConfig: runtimeConfig,
                providerID: providerID,
                modelID: modelID,
                apiKey: apiKey,
                client: client,
                targetLanguage: lang
            )
        }
        cancellables[article.id] = task
        defer { cancellables[article.id] = nil }
        try await task.value
        if let result = findCachedTranslation(for: article, targetLanguage: lang) {
            return result
        }
        throw AIProviderError.providerError("翻译未生成")
    }

    func cancel(articleID: String) {
        cancellables[articleID]?.cancel()
        cancellables[articleID] = nil
    }

    func translateSelection(text: String, context: String, targetLanguage: String) async throws -> SelectionTranslation {
        let provider = persistence.defaultProvider()
        guard let provider else { throw AIProviderError.invalidConfig("未配置 AI Provider") }
        let apiKey = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtimeConfig = ProviderRuntimeConfig(provider).disablingReasoningForTranslation()
        let client = factory.makeClient(for: runtimeConfig.kind)

        let prompt = Self.selectionPrompt(selectedText: text, context: context, targetLanguage: targetLanguage)
        let messages: [AIMessage] = [.system(prompt.system), .user(prompt.user)]
        let raw = try await client.generateText(messages: messages, config: runtimeConfig, apiKey: apiKey)
        let json = Self.extractJSON(from: raw)
        guard let data = json?.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SelectionTranslation.self, from: data) else {
            return SelectionTranslation(translation: raw, partOfSpeech: nil, explanation: nil, example: nil, confidence: 0.6)
        }
        return decoded
    }

    private func runTranslation(
        article: Article,
        runtimeConfig: ProviderRuntimeConfig,
        providerID: String,
        modelID: String,
        apiKey: String,
        client: AIProviderClient,
        targetLanguage: String
    ) async throws -> ArticleTranslation {
        let sourceLanguage = article.languageCode.isEmpty ? "auto" : article.languageCode
        let contentForTranslation = article.bodyText ?? article.summary ?? ""
        let contentHash = TranslationCache.contentHash(title: article.title, summary: article.summary, body: article.bodyText)
        let titleAndSummary = "\(article.title)\n\n\(contentForTranslation)"

        let prompt = Self.articlePrompt(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, content: titleAndSummary)
        let messages: [AIMessage] = [.system(prompt.system), .user(prompt.user)]
        let raw = try await client.generateText(messages: messages, config: runtimeConfig, apiKey: apiKey)

        let translation: ArticleTranslation
        if let decoded = Self.decodeArticleTranslationPayload(from: raw) {
            translation = ArticleTranslation(
                articleID: article.id,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                translatedTitle: decoded.titleZh ?? article.title,
                translatedSummary: decoded.summaryZh,
                translatedBody: decoded.bodyZh,
                paragraphsJSON: Self.encodeParagraphs(decoded.paragraphs),
                keyTermsJSON: Self.encodeKeyTerms(decoded.keyTerms),
                model: modelID,
                providerID: providerID,
                contentHash: contentHash
            )
        } else {
            let cleaned = Self.cleanPlainTranslation(raw)
            // Treat as plain text translation
            translation = ArticleTranslation(
                articleID: article.id,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                translatedTitle: cleaned.split(separator: "\n").first.map(String.init) ?? article.title,
                translatedSummary: nil,
                translatedBody: cleaned,
                paragraphsJSON: nil,
                keyTermsJSON: nil,
                model: modelID,
                providerID: providerID,
                contentHash: contentHash
            )
        }
        persistence.container.mainContext.insert(translation)
        persistence.save()
        return translation
    }

    private func findCachedTranslation(for article: Article, targetLanguage lang: String) -> ArticleTranslation? {
        guard let cached = persistence.fetchTranslation(articleID: article.id, targetLanguage: lang, model: persistence.defaultProvider()?.modelID ?? "") else {
            return nil
        }
        if let hash = cached.contentHash {
            let current = TranslationCache.contentHash(title: article.title, summary: article.summary, body: article.bodyText)
            if hash != current { return nil }
        }
        return cached
    }

    private func ensureFullContentIfNeeded(for article: Article) async {
        let hasNoBody = article.bodyParagraphs.isEmpty
        let hasBoilerplate = article.bodyText.map(ContentExtractor.containsBoilerplateNoise) ?? false
        guard (hasNoBody || hasBoilerplate), let url = article.url else { return }
        guard let content = try? await contentService.fetchContent(url: url) else { return }
        if let bodyText = content.bodyText, !bodyText.isEmpty {
            article.bodyText = bodyText
            article.contentHash = ArticleNormalizer.contentHash(title: article.title, summary: bodyText)
        }
        if article.author == nil {
            article.author = content.author
        }
        let mergedImages = mergeImageURLs(primary: article.imageURLString, extracted: content.imageURLStrings)
        if !mergedImages.isEmpty {
            article.imageURLString = mergedImages.first
            article.imageURLsString = mergedImages.joined(separator: "\n")
        }
        persistence.save()
    }

    private func mergeImageURLs(primary: String?, extracted: [String]) -> [String] {
        var values = extracted
        if let primary, !primary.isEmpty {
            values.insert(primary, at: 0)
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    nonisolated static func articlePrompt(sourceLanguage: String, targetLanguage: String, content: String) -> (system: String, user: String) {
        let langName = Self.displayName(forLanguage: targetLanguage)
        let system = """
        你是专业新闻译者。请将下面新闻翻译为\(langName)。
        要求：
        1. 保留事实，不添加原文没有的信息。
        2. 新闻机构、人名、地名首次出现时保留英文原名。
        3. 数字、日期、专有名词准确。
        4. 语气保持新闻报道风格，简洁、自然。
        5. 返回严格 JSON，格式如下：
        {"title_zh":"标题","summary_zh":"摘要","body_zh":"正文译文","paragraphs":[{"index":0,"source":"原文段落","translation":"中文段落"}],"key_terms":[{"term":"term","translation":"中文","explanation":"新闻语境解释"}]}
        """
        let user = "原文：\n\(content)"
        return (system, user)
    }

    nonisolated static func selectionPrompt(selectedText: String, context: String, targetLanguage: String) -> (system: String, user: String) {
        let langName = Self.displayName(forLanguage: targetLanguage)
        let system = """
        请把用户在新闻中选中的词或短句翻译为\(langName)。返回严格 JSON：
        {"translation":"中文译文","partOfSpeech":"词性","explanation":"新闻语境解释","example":"例句（可选）","confidence":0.0}
        confidence 取 0~1。
        """
        let user = """
        上下文：
        \(context)

        选中文本：
        \(selectedText)
        """
        return (system, user)
    }

    nonisolated static func displayName(forLanguage code: String) -> String {
        switch code {
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        case "en": return "English"
        default: return code
        }
    }

    nonisolated static func extractJSON(from raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if s.hasSuffix("```") {
                s = String(s.dropLast(3))
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return nil
    }

    nonisolated static func decodeArticleTranslationPayload(from raw: String) -> ArticleTranslationPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []
        if let json = extractJSON(from: trimmed) {
            candidates.append(json)
        }
        if trimmed.contains(#""title_zh""#) || trimmed.contains(#""body_zh""#) {
            let wrapped = trimmed.hasPrefix("{") ? trimmed : "{\(trimmed)}"
            candidates.append(wrapped)
        }
        for candidate in candidates {
            if let data = candidate.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ArticleTranslationPayload.self, from: data) {
                return decoded
            }
        }
        let payload = ArticleTranslationPayload(
            titleZh: extractJSONStringValue("title_zh", from: trimmed),
            summaryZh: extractJSONStringValue("summary_zh", from: trimmed),
            bodyZh: extractJSONStringValue("body_zh", from: trimmed),
            paragraphs: nil,
            keyTerms: nil
        )
        return payload.hasContent ? payload : nil
    }

    nonisolated static func cleanPlainTranslation(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func extractJSONStringValue(_ key: String, from raw: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #""# + escapedKey + #""\s*:\s*"((?:\\.|[^"\\])*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = raw as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              match.numberOfRanges >= 2 else { return nil }
        let encodedValue = ns.substring(with: match.range(at: 1))
        let jsonString = "\"\(encodedValue)\""
        if let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return encodedValue
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func encodeParagraphs(_ paragraphs: [TranslatedParagraph]?) -> String? {
        guard let paragraphs, !paragraphs.isEmpty else { return nil }
        return (try? String(data: JSONEncoder().encode(paragraphs), encoding: .utf8))
    }

    nonisolated static func encodeKeyTerms(_ terms: [KeyTerm]?) -> String? {
        guard let terms, !terms.isEmpty else { return nil }
        return (try? String(data: JSONEncoder().encode(terms), encoding: .utf8))
    }
}

struct ArticleTranslationPayload: Codable {
    let titleZh: String?
    let summaryZh: String?
    let bodyZh: String?
    let paragraphs: [TranslatedParagraph]?
    let keyTerms: [KeyTerm]?

    enum CodingKeys: String, CodingKey {
        case titleZh = "title_zh"
        case summaryZh = "summary_zh"
        case bodyZh = "body_zh"
        case paragraphs
        case keyTerms = "key_terms"
    }

    var hasContent: Bool {
        !(titleZh?.isEmpty ?? true) || !(summaryZh?.isEmpty ?? true) || !(bodyZh?.isEmpty ?? true)
    }
}
