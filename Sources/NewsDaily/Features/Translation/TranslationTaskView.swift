import SwiftUI

struct TranslationTaskView: View {
    let articleID: String
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)
            Text("正在翻译…")
                .font(.headline)
            if let progress = appState.translationProgress[articleID] {
                Text(stageText(progress))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if progress.total > 0 {
                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                        .frame(width: 240)
                }
                if let msg = progress.message {
                    Text(msg).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Button("取消") {
                appState.cancelTranslation(articleID: articleID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func stageText(_ progress: TranslationProgress) -> String {
        switch progress.stage {
        case .preparing: return "准备中"
        case .chunking: return "分块中"
        case .translatingChunks: return "翻译中"
        case .merging: return "合并结果"
        case .finalizing: return "收尾"
        case .done: return "完成"
        case .failed: return "失败"
        }
    }
}
