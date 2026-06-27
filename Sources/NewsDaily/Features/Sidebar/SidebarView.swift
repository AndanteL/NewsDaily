import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var sources: [NewsSource] = []

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedSidebar },
            set: { appState.selectedSidebar = $0 ?? .today }
        )) {
            Section("浏览") {
                Label("今日热点", systemImage: "flame.fill")
                    .tag(SidebarSelection.today)
                Label("全部新闻", systemImage: "tray.full")
                    .tag(SidebarSelection.all)
                Label("收藏", systemImage: "star.fill")
                    .tag(SidebarSelection.favorites)
                Label("稍后读", systemImage: "bookmark.fill")
                    .tag(SidebarSelection.readLater)
            }
            Section("来源") {
                ForEach(sources) { source in
                    HStack {
                        Label(source.name, systemImage: "dot.radiowaves.left.and.right")
                            .help(source.homepageURLString)
                        Spacer()
                        if let err = source.lastErrorMessage, !err.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help(err)
                        }
                    }
                    .tag(SidebarSelection.source(source.id))
                }
            }
            Section("学习") {
                Label("生词本", systemImage: "text.book.closed")
                    .tag(SidebarSelection.vocabulary)
            }
        }
        .listStyle(.sidebar)
        .navigationSubtitle(subtitleText)
        .onAppear { reload() }
        .onChange(of: appState.lastRefreshSummary?.finishedAt) { _, _ in reload() }
    }

    private var subtitleText: String {
        if appState.isRefreshing { return "正在刷新…" }
        if let s = appState.lastRefreshSummary {
            return "新增 \(s.newArticles) 条 · \(s.sourcesSucceeded) 源成功"
        }
        return "已就绪"
    }

    private func reload() {
        sources = appState.persistence.fetchSources()
    }
}
