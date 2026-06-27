import SwiftUI

enum TranslationPopoverAction {
    case save(translation: String, explanation: String?, partOfSpeech: String?)
    case dismiss
}

struct TranslationPopover: View {
    let selection: SelectionContext
    let onAction: (TranslationPopoverAction) -> Void

    @State private var translation: String = ""
    @State private var explanation: String?
    @State private var partOfSpeech: String?
    @State private var example: String?
    @State private var confidence: Double = 0
    @State private var isLoading: Bool = true
    @State private var error: String?
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("选词翻译")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            Text(selection.text)
                .font(.system(.body, design: .serif))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            } else if !translation.isEmpty {
                Text(translation)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                if let pos = partOfSpeech, !pos.isEmpty {
                    Text("【词性】\(pos)").font(.caption).foregroundStyle(.secondary)
                }
                if let explanation, !explanation.isEmpty {
                    Text("【语境】\(explanation)").font(.caption).foregroundStyle(.secondary)
                }
                if let example, !example.isEmpty {
                    Text("【例】\(example)").font(.caption).foregroundStyle(.tertiary)
                }
            }

            HStack {
                if !translation.isEmpty {
                    Button("加入生词本") {
                        onAction(.save(translation: translation, explanation: explanation, partOfSpeech: partOfSpeech))
                    }
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translation, forType: .string)
                    }
                }
                Spacer()
                Button("重新翻译") { translate() }
                Button("关闭") { onAction(.dismiss) }
            }
        }
        .padding()
        .onAppear { translate() }
    }

    private func translate() {
        isLoading = true
        error = nil
        translation = ""
        explanation = nil
        partOfSpeech = nil
        example = nil
        Task {
            do {
                let result = try await appState.translationService.translateSelection(
                    text: selection.text,
                    context: "",
                    targetLanguage: appState.settings.targetLanguage
                )
                translation = result.translation
                explanation = result.explanation
                partOfSpeech = result.partOfSpeech
                example = result.example
                confidence = result.confidence
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}
