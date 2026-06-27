import SwiftUI

struct ParallelTranslationView: View {
    let article: Article
    let translation: ArticleTranslation?

    var body: some View {
        if let translation {
            let rows = parallelRows(article: article, translation: translation)
            if rows.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let body = translation.translatedBody, !body.isEmpty {
                            Text(body)
                                .font(.system(size: 15))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let summary = translation.translatedSummary {
                            Text(translation.translatedTitle)
                                .font(.title3.bold())
                            Text(summary)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(translation.translatedTitle)
                            .font(.title3.bold())
                        ForEach(rows) { row in
                            parallelRow(row)
                        }
                        if !translation.keyTerms.isEmpty {
                            Divider()
                            Text("关键词").font(.headline)
                            ForEach(translation.keyTerms, id: \.self) { term in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(term.term) — \(term.translation)").bold()
                                    if let explanation = term.explanation {
                                        Text(explanation).foregroundStyle(.secondary).font(.callout)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        } else {
            Text("尚无翻译")
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func parallelRow(_ row: ParallelRow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("原文")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text(row.source)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("译文")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text(row.translation)
                    .font(.system(size: 15))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func parallelRows(article: Article, translation: ArticleTranslation) -> [ParallelRow] {
        let structured = translation.paragraphs
            .sorted { $0.index < $1.index }
            .enumerated()
            .map { ParallelRow(id: $0.offset, source: $0.element.source, translation: $0.element.translation) }
            .filter { !$0.source.isEmpty || !$0.translation.isEmpty }
        if !structured.isEmpty {
            return structured
        }

        let sourceParagraphs = ContentExtractor.sanitizeParagraphs(article.bodyParagraphs)
        let translatedParagraphs = translationBodyParagraphs(translation)
        let count = max(sourceParagraphs.count, translatedParagraphs.count)
        guard count > 0 else { return [] }

        return (0..<count).map { index in
            ParallelRow(
                id: index,
                source: index < sourceParagraphs.count ? sourceParagraphs[index] : "",
                translation: index < translatedParagraphs.count ? translatedParagraphs[index] : ""
            )
        }
    }

    private func translationBodyParagraphs(_ translation: ArticleTranslation) -> [String] {
        guard let body = translation.translatedBody else {
            return translation.translatedSummary.map { [$0] } ?? []
        }
        return body
            .replacingOccurrences(of: "\\n", with: "\n")
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct ParallelRow: Identifiable, Hashable {
    let id: Int
    let source: String
    let translation: String
}
