import SwiftUI
import SwiftData

struct VocabularyView: View {
    @EnvironmentObject private var appState: AppState
    @State private var items: [VocabularyItem] = []
    @State private var search: String = ""
    @State private var onlyUnmastered: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                MacSearchField(placeholder: "搜索生词", text: $search)
                    .frame(width: 220, height: 28)
                Toggle("仅未掌握", isOn: $onlyUnmastered)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("刷新") { reload() }
            }
            .padding(12)

            Divider()

            Group {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text(search.isEmpty ? "阅读时选中词语即可加入生词本" : "没有匹配的生词")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(items) {
                        TableColumn("词") { item in
                            Text(item.text).bold()
                        }
                        TableColumn("翻译") { item in
                            Text(item.translation)
                        }
                        TableColumn("语境") { item in
                            Text(item.explanation ?? "").foregroundStyle(.secondary).font(.callout)
                        }
                        TableColumn("来源") { item in
                            Text(item.articleTitle ?? "").foregroundStyle(.tertiary).lineLimit(1)
                        }
                        TableColumn("创建") { item in
                            Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        TableColumn("操作") { item in
                            HStack {
                                Button("已掌握") { toggleMastered(item) }
                                Button("删除", role: .destructive) { delete(item) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: onlyUnmastered) { _, _ in reload() }
        .onChange(of: search) { _, _ in reload() }
    }

    private func reload() {
        items = appState.persistence.fetchVocabulary(search: search.isEmpty ? nil : search, includeMastered: !onlyUnmastered)
    }

    private func toggleMastered(_ item: VocabularyItem) {
        item.isMastered.toggle()
        item.lastReviewedAt = .now
        item.reviewCount += 1
        appState.persistence.save()
        reload()
    }

    private func delete(_ item: VocabularyItem) {
        appState.persistence.delete(item)
        appState.persistence.save()
        reload()
    }
}
