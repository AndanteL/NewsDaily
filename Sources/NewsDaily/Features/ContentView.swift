import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var sidebarWidth: CGFloat = 220
    @State private var listWidth: CGFloat = 360

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: sidebarWidth, max: 320)
        } content: {
            if case .vocabulary = appState.selectedSidebar {
                VocabularyView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: listWidth, max: 520)
            } else {
                ArticleListView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: listWidth, max: 520)
            }
        } detail: {
            ReaderContainerView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await appState.refreshAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新 (⌘R)")
                .disabled(appState.isRefreshing)

                if appState.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                SearchFieldView()
                    .frame(width: 220)

                Button {
                    if let id = appState.selectedArticleID,
                       let article = appState.persistence.fetchArticle(id: id) {
                        Task { await appState.requestTranslation(for: article) }
                    }
                } label: {
                    Label("翻译", systemImage: "character.book.closed")
                }
                .help("翻译当前文章 (⌘T)")

                Button {
                    openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("NewsDaily")
        .alert("提示", isPresented: Binding(
            get: { appState.lastError != nil },
            set: { if !$0 { appState.lastError = nil } }
        )) {
            Button("好") { appState.lastError = nil }
        } message: {
            Text(appState.lastError ?? "")
        }
    }
}

private struct SearchFieldView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MacSearchField(
            placeholder: "搜索新闻标题或摘要",
            text: $appState.search,
            focusNotification: .focusSearchField
        )
        .frame(height: 28)
    }
}

private struct ReaderContainerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let id = appState.selectedArticleID,
               let article = appState.persistence.fetchArticle(id: id) {
                ReaderView(article: article)
                    .id(article.id)
            } else {
                EmptyReaderView()
            }
        }
    }
}

private struct EmptyReaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
            Text("选择左侧新闻开始阅读")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("支持快捷键 ⌘R 刷新 / ⌘F 搜索 / ⌘T 翻译")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
