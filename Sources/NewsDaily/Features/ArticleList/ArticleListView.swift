import SwiftUI
import SwiftData

struct ArticleListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var articles: [Article] = []
    @State private var sources: [String: NewsSource] = [:]

    var body: some View {
        Group {
            if articles.isEmpty {
                EmptyListView(searching: !appState.search.isEmpty)
            } else {
                List(selection: Binding(
                    get: { appState.selectedArticleID },
                    set: { newValue in
                        appState.selectedArticleID = newValue
                        if let id = newValue, let article = articles.first(where: { $0.id == id }) {
                            appState.markRead(article)
                        }
                    }
                )) {
                    ForEach(articles) { article in
                        ArticleRowView(article: article, sourceName: sources[article.sourceID]?.name ?? article.sourceID)
                            .tag(article.id)
                    }
                }
                .listStyle(.inset)
                .contextMenu {
                    if let id = appState.selectedArticleID,
                       let article = articles.first(where: { $0.id == id }) {
                        Button(article.isFavorite ? "取消收藏" : "收藏") {
                            appState.toggleFavorite(article)
                        }
                        Button(article.readLater ? "移出稍后读" : "加入稍后读") {
                            appState.toggleReadLater(article)
                        }
                        Button("翻译") {
                            Task { await appState.requestTranslation(for: article) }
                        }
                        Divider()
                        Button("在浏览器打开") {
                            if let url = article.url { NSWorkspace.shared.open(url) }
                        }
                        Button("删除", role: .destructive) {
                            appState.deleteArticle(article)
                        }
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: appState.selectedSidebar) { _, _ in reload() }
        .onChange(of: appState.search) { _, _ in reload() }
        .onChange(of: appState.lastRefreshSummary?.finishedAt) { _, _ in reload() }
    }

    private func reload() {
        let s = appState.persistence.fetchSources()
        sources = Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0) })
        articles = appState.articlesForCurrentSelection()
    }
}

private struct EmptyListView: View {
    let searching: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: searching ? "magnifyingglass" : "newspaper")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text(searching ? "没有匹配的新闻" : "暂无新闻，点击刷新")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
