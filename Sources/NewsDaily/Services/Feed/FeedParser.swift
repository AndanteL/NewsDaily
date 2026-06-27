import Foundation

protocol FeedParsing {
    func parse(data: Data, source: NewsSource) throws -> [ArticleDraft]
}

enum FeedParseError: LocalizedError {
    case malformedXML
    case unsupportedFormat
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .malformedXML: return "RSS/Atom 源 XML 格式不正确"
        case .unsupportedFormat: return "不支持的订阅源格式（仅支持 RSS 2.0 / Atom 1.0）"
        case .missingField(let f): return "缺少必要字段: \(f)"
        }
    }
}

struct FeedParser: FeedParsing {
    func parse(data: Data, source: NewsSource) throws -> [ArticleDraft] {
        let parser = FeedXMLParser(source: source)
        return try parser.parse(data: data)
    }
}

private final class FeedXMLParser: NSObject, XMLParserDelegate {
    private let source: NewsSource
    private var drafts: [ArticleDraft] = []

    private var currentElement: String = ""
    private var currentText: String = ""
    private var currentItem: [String: String] = [:]
    private var inItem: Bool = false
    private var format: FeedFormat = .unknown
    private var error: Error?

    enum FeedFormat { case unknown, rss, atom }

    init(source: NewsSource) {
        self.source = source
    }

    func parse(data: Data) throws -> [ArticleDraft] {
        let xml = XMLParser(data: data)
        xml.delegate = self
        xml.shouldProcessNamespaces = false
        if !xml.parse() {
            if let err = error { throw err }
            throw FeedParseError.malformedXML
        }
        if format == .unknown { throw FeedParseError.unsupportedFormat }
        return drafts
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""

        if currentElement == "rss" {
            format = .rss
        } else if currentElement == "feed" {
            format = .atom
        } else if currentElement == "item" || currentElement == "entry" {
            inItem = true
            currentItem = [:]
        } else if currentElement == "link" && inItem && format == .atom {
            if let href = attributeDict["href"], !href.isEmpty {
                currentItem["link"] = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            currentText.append(s)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch name {
            case "title":
                currentItem["title"] = (currentItem["title"] ?? "") + value
            case "description", "summary", "content":
                if currentItem["description"] == nil || (currentItem["description"]?.isEmpty ?? true) {
                    currentItem["description"] = value
                }
            case "link":
                if format == .rss, !value.isEmpty {
                    currentItem["link"] = (currentItem["link"] ?? "") + value
                }
            case "guid", "id":
                if currentItem["guid"] == nil {
                    currentItem["guid"] = value
                }
            case "pubdate", "published", "updated":
                if currentItem["pubdate"] == nil {
                    currentItem["pubdate"] = value
                } else if name == "updated" {
                    currentItem["pubdate"] = value
                }
            case "author", "dc:creator":
                if currentItem["author"] == nil {
                    currentItem["author"] = value
                }
            case "media:content", "media:thumbnail", "enclosure":
                break
            case "item", "entry":
                inItem = false
                if let draft = makeDraft() {
                    drafts.append(draft)
                }
            default:
                break
            }
        }
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }

    private func makeDraft() -> ArticleDraft? {
        guard let title = currentItem["title"]?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        let link = currentItem["link"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let guid = currentItem["guid"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty || !(guid?.isEmpty ?? true) else { return nil }

        let summary = currentItem["description"]?
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = (summary?.isEmpty ?? true) ? nil : summary

        let publishedAt = currentItem["pubdate"].flatMap { FeedDateParser.parse($0) }

        let finalURL = link.isEmpty ? (guid ?? "") : link

        return ArticleDraft(
            sourceID: source.id,
            title: title,
            summary: trimmedSummary,
            urlString: finalURL,
            publishedAt: publishedAt,
            author: currentItem["author"],
            imageURLString: nil,
            languageCode: source.languageCode,
            guid: guid
        )
    }
}

enum FeedDateParser {
    static let formatters: [DateFormatter] = {
        let templates: [(String, String?)] = [
            ("EEE, dd MMM yyyy HH:mm:ss zzz", "en_US_POSIX"),
            ("EEE, dd MMM yyyy HH:mm:ss Z", "en_US_POSIX"),
            ("EEE, d MMM yyyy HH:mm:ss zzz", "en_US_POSIX"),
            ("EEE, d MMM yyyy HH:mm:ss Z", "en_US_POSIX"),
            ("yyyy-MM-dd'T'HH:mm:ssZZZZZ", "en_US_POSIX"),
            ("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ", "en_US_POSIX"),
            ("yyyy-MM-dd'T'HH:mm:ssXXXXX", "en_US_POSIX"),
            ("yyyy-MM-dd HH:mm:ss", "en_US_POSIX"),
            ("EEE MMM d HH:mm:ss yyyy", "en_US_POSIX")
        ]
        return templates.map { template, locale in
            let f = DateFormatter()
            f.dateFormat = template
            if let l = locale { f.locale = Locale(identifier: l) }
            return f
        }
    }()

    static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        for f in formatters {
            if let d = f.date(from: trimmed) { return d }
        }
        let iso = ISO8601DateFormatter()
        return iso.date(from: trimmed)
    }
}
