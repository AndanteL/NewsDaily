import SwiftUI
import WebKit

struct ReaderView: View {
    @EnvironmentObject private var appState: AppState
    let article: Article
    private let contentService = ArticleContentService()

    @State private var selectedTab: ReaderTab = .original
    @State private var translation: ArticleTranslation?
    @State private var translationError: String?
    @State private var translating: Bool = false
    @State private var loadProgress: Double = 0
    @State private var loadingFullContent: Bool = false
    @State private var selectionInfo: SelectionContext?

    enum ReaderTab: String, CaseIterable, Identifiable {
        case original
        case translation
        case parallel
        case web

        var id: String { rawValue }

        var title: String {
            switch self {
            case .original: return "原文正文"
            case .translation: return "AI 翻译"
            case .parallel: return "双语对照"
            case .web: return "网页全文"
            }
        }

        var helpText: String {
            switch self {
            case .original: return "应用内排版显示抓取到的正文和图片"
            case .translation: return "显示或生成当前文章的 AI 翻译"
            case .parallel: return "左右对照查看原文与译文"
            case .web: return "加载新闻网站原始网页全文"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabSelector
            Divider()
            selectedContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: article.id) {
            await loadArticleState()
        }
        .popover(item: $selectionInfo) { info in
            TranslationPopover(selection: info) { action in
                handlePopoverAction(action, info: info)
            }
            .frame(width: 320)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(article.title)
                    .font(.system(size: 18, weight: .semibold))
                    .textSelection(.enabled)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(article.sourceID)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                if let date = article.publishedAt {
                    Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let url = article.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("在浏览器打开", systemImage: "safari")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Spacer()
                Button {
                    appState.toggleFavorite(article)
                } label: {
                    Image(systemName: article.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(article.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                Button {
                    appState.toggleReadLater(article)
                } label: {
                    Image(systemName: article.readLater ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(article.readLater ? .teal : .secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
    }

    private var tabSelector: some View {
        Picker("阅读模式", selection: $selectedTab) {
            ForEach(ReaderTab.allCases) { tab in
                Text(tab.title)
                    .tag(tab)
                    .help(tab.helpText)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .original:
            originalTab
        case .translation:
            translationTab
        case .parallel:
            parallelTab
        case .web:
            webTab
        }
    }

    @ViewBuilder
    private var originalTab: some View {
        VStack(spacing: 0) {
            if loadingFullContent {
                ProgressView("正在获取原文正文...")
                    .controlSize(.small)
                    .padding(.top, 10)
            }
            if !article.imageURLs.isEmpty {
                originalImageStrip
                Divider()
            }
            SelectableTextView(
                attributedText: buildOriginalAttributedString(),
                onSelection: handleTextSelection
            )
        }
    }

    private var originalImageStrip: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 12) {
                ForEach(article.imageURLs, id: \.absoluteString) { url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay { ProgressView().controlSize(.small) }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 240, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 160)
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var translationTab: some View {
        VStack(spacing: 0) {
            if let t = currentTranslation {
                SelectableTextView(
                    attributedText: buildTranslationAttributedString(from: t),
                    onSelection: handleTextSelection
                )
            } else if translating {
                TranslationTaskView(articleID: article.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.tertiary)
                    if let err = translationError {
                        Text("翻译失败: \(err)").font(.callout).foregroundStyle(.red)
                    } else {
                        Text("点击翻译当前文章")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Button("翻译") {
                        startTranslation()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var parallelTab: some View {
        ParallelTranslationView(article: article, translation: currentTranslation)
            .overlay(alignment: .bottomTrailing) {
                if currentTranslation == nil && !translating {
                    Button("生成翻译") { startTranslation() }
                        .padding()
                }
            }
    }

    @ViewBuilder
    private var webTab: some View {
        VStack(spacing: 0) {
            if loadProgress > 0 && loadProgress < 1 {
                ProgressView(value: loadProgress)
                    .progressViewStyle(.linear)
            }
            if let url = article.url {
                WebReaderView(url: url, loadProgress: $loadProgress)
            } else {
                Text("文章无 URL")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func startTranslation() {
        Task {
            await translateCurrentArticle()
        }
    }

    private func translateCurrentArticle() async {
        guard !translating else { return }
        translationError = nil
        translating = true
        await appState.requestTranslation(for: article)
        translating = false
        translation = fetchCurrentTranslation()
        if translation == nil {
            translationError = appState.lastError
        }
    }

    private var currentTranslation: ArticleTranslation? {
        guard let translation, isCurrentTranslation(translation) else { return nil }
        return translation
    }

    private func loadArticleState() async {
        translation = nil
        translationError = nil
        translating = false
        loadingFullContent = false
        loadProgress = 0
        selectionInfo = nil
        let storedBeforeLoadingContent = fetchStoredTranslation()
        translation = currentTranslation(from: storedBeforeLoadingContent)
        if appState.settings.showReaderTranslationByDefault {
            selectedTab = .translation
        }
        let didLoadFullContent = await loadFullContentIfNeeded()
        translation = fetchCurrentTranslation()
        let shouldRefreshStaleTranslation = storedBeforeLoadingContent != nil && translation == nil && !article.bodyParagraphs.isEmpty
        if translation == nil,
           didLoadFullContent || shouldRefreshStaleTranslation || selectedTab == .translation || appState.settings.showReaderTranslationByDefault {
            await translateCurrentArticle()
        }
    }

    private func fetchStoredTranslation() -> ArticleTranslation? {
        appState.persistence.fetchTranslation(
            articleID: article.id,
            targetLanguage: appState.settings.targetLanguage,
            model: appState.persistence.defaultProvider()?.modelID ?? ""
        )
    }

    private func fetchCurrentTranslation() -> ArticleTranslation? {
        currentTranslation(from: fetchStoredTranslation())
    }

    private func currentTranslation(from fetched: ArticleTranslation?) -> ArticleTranslation? {
        guard let fetched, isCurrentTranslation(fetched) else { return nil }
        return fetched
    }

    private func isCurrentTranslation(_ candidate: ArticleTranslation) -> Bool {
        guard candidate.articleID == article.id else { return false }
        let currentHash = TranslationCache.contentHash(title: article.title, summary: article.summary, body: article.bodyText)
        guard let cachedHash = candidate.contentHash else {
            return article.bodyText?.isEmpty ?? true
        }
        return cachedHash == currentHash
    }

    private func handleTextSelection(_ text: String, _ rect: NSRect) {
        selectionInfo = SelectionContext(text: text, source: .text, screenRect: rect, articleID: article.id)
    }

    @discardableResult
    private func loadFullContentIfNeeded() async -> Bool {
        guard (article.bodyParagraphs.isEmpty || bodyContainsBoilerplateNoise()), let url = article.url else { return false }
        loadingFullContent = true
        defer { loadingFullContent = false }
        guard let content = try? await contentService.fetchContent(url: url) else { return false }
        var didUpdate = false
        if let bodyText = content.bodyText, !bodyText.isEmpty {
            article.bodyText = bodyText
            article.contentHash = ArticleNormalizer.contentHash(title: article.title, summary: bodyText)
            didUpdate = true
        }
        if article.author == nil {
            article.author = content.author
            didUpdate = didUpdate || content.author != nil
        }
        let mergedImages = mergeImageURLs(primary: article.imageURLString, extracted: content.imageURLStrings)
        if !mergedImages.isEmpty {
            article.imageURLString = mergedImages.first
            article.imageURLsString = mergedImages.joined(separator: "\n")
            didUpdate = true
        }
        appState.persistence.save()
        return didUpdate
    }

    private func buildOriginalAttributedString() -> NSAttributedString {
        let attr = NSMutableAttributedString()
        let paragraphs = cleanedOriginalParagraphs()
        if !paragraphs.isEmpty {
            attr.append(NSAttributedString(string: article.title, attributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: originalTitleParagraphStyle
            ]))
            if let author = article.author, !author.isEmpty {
                attr.append(NSAttributedString(string: "\n\n\(author)", attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: originalMetaParagraphStyle
                ]))
            }
            attr.append(NSAttributedString(string: "\n\n"))
            for (index, paragraph) in paragraphs.enumerated() {
                if index > 0 {
                    attr.append(NSAttributedString(string: "\n\n"))
                }
                attr.append(NSAttributedString(string: paragraph, attributes: [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: originalParagraphStyle
                ]))
            }
        } else if let summary = article.summary, !summary.isEmpty {
            attr.append(NSAttributedString(string: summary, attributes: [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: originalParagraphStyle
            ]))
            attr.append(NSAttributedString(string: "\n\n正在尝试获取原文全文。", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]))
        } else {
            attr.append(NSAttributedString(string: "暂未获取到原文正文。", attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]))
        }
        return attr
    }

    private func cleanedOriginalParagraphs() -> [String] {
        ContentExtractor.sanitizeParagraphs(article.bodyParagraphs)
    }

    private func bodyContainsBoilerplateNoise() -> Bool {
        guard let bodyText = article.bodyText, !bodyText.isEmpty else { return false }
        return ContentExtractor.containsBoilerplateNoise(bodyText)
    }

    private var originalTitleParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 8
        return style
    }

    private var originalMetaParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 8
        return style
    }

    private var originalParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 12
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private func buildTranslationAttributedString(from t: ArticleTranslation) -> NSAttributedString {
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: cleanDisplayText(t.translatedTitle), attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: titleParagraphStyle
        ]))
        attr.append(NSAttributedString(string: "\n\n"))
        attr.append(NSAttributedString(string: "AI 翻译 · \(t.model)", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: translationMetaParagraphStyle
        ]))
        if let summary = t.translatedSummary, !summary.isEmpty {
            attr.append(NSAttributedString(string: "\n\n"))
            attr.append(NSAttributedString(string: cleanDisplayText(summary), attributes: [
                .font: NSFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: translationLeadParagraphStyle
            ]))
        }

        let bodyParagraphs = translationBodyParagraphs(from: t)
        if !bodyParagraphs.isEmpty {
            attr.append(NSAttributedString(string: "\n\n"))
            for (index, paragraph) in bodyParagraphs.enumerated() {
                if index > 0 {
                    attr.append(NSAttributedString(string: "\n\n"))
                }
                attr.append(NSAttributedString(string: paragraph, attributes: [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: translationBodyParagraphStyle
                ]))
            }
        }

        if !t.keyTerms.isEmpty {
            attr.append(NSAttributedString(string: "\n\n关键术语\n", attributes: [
                .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: translationSectionTitleParagraphStyle
            ]))
            for term in t.keyTerms {
                let explanation = term.explanation.map { "：\($0)" } ?? ""
                attr.append(NSAttributedString(string: "\n\(term.term) - \(term.translation)\(explanation)", attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: translationBodyParagraphStyle
                ]))
            }
        }
        return attr
    }

    private func translationBodyParagraphs(from translation: ArticleTranslation) -> [String] {
        let structured = translation.paragraphs
            .sorted { $0.index < $1.index }
            .map { cleanDisplayText($0.translation) }
            .filter { !$0.isEmpty }
        if !structured.isEmpty {
            return structured
        }
        guard let body = translation.translatedBody else { return [] }
        let summary = translation.translatedSummary.map(cleanDisplayText)
        return cleanDisplayText(body)
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != summary }
    }

    private func cleanDisplayText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 8
        return style
    }

    private var translationMetaParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 4
        return style
    }

    private var translationLeadParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = 12
        return style
    }

    private var translationBodyParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 10
        return style
    }

    private var translationSectionTitleParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 6
        return style
    }

    private func handlePopoverAction(_ action: TranslationPopoverAction, info: SelectionContext) {
        switch action {
        case .save(let translation, let explanation, let partOfSpeech):
            saveVocabulary(text: info.text, translation: translation, explanation: explanation, partOfSpeech: partOfSpeech)
        case .dismiss:
            selectionInfo = nil
        }
    }

    private func saveVocabulary(text: String, translation: String, explanation: String?, partOfSpeech: String?) {
        let item = VocabularyItem(
            text: text,
            sourceText: text,
            translation: translation,
            explanation: explanation,
            partOfSpeech: partOfSpeech,
            articleID: article.id,
            articleTitle: article.title,
            languageCode: article.languageCode
        )
        appState.persistence.container.mainContext.insert(item)
        appState.persistence.save()
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

struct SelectionContext: Identifiable {
    let id = UUID()
    let text: String
    let source: SelectionSource
    let screenRect: NSRect?
    let articleID: String

    enum SelectionSource { case text, web }
}
