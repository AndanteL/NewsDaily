import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let sourceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(article.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .foregroundStyle(article.isRead ? .secondary : .primary)
                Spacer(minLength: 4)
                if article.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                if article.readLater {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Text(sourceName)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                if let date = article.publishedAt {
                    Text(relativeTimeString(date))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if !article.keywords.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(article.keywords.prefix(3), id: \.self) { kw in
                            Text(kw)
                                .font(.system(size: 10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func relativeTimeString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
