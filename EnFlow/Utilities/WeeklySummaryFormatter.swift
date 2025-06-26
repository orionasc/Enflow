import Foundation

enum WeeklySummaryFormatter {
    private struct Summary: Decodable {
        struct Section: Decodable { let title: String; let content: String }
        struct Event: Decodable { let title: String; let date: String }
        let sections: [Section]
        let events: [Event]
    }

    static func format(from raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON substring if extraneous text surrounds it
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        if let data = cleaned.data(using: .utf8),
           let summary = try? JSONDecoder().decode(Summary.self, from: data) {
            return buildText(from: summary)
        }

        if let data = cleaned.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let sections = (obj["sections"] as? [[String: Any]]) ?? []
            let events = (obj["events"] as? [[String: Any]]) ?? []
            let summary = Summary(
                sections: sections.map {
                    Summary.Section(title: $0["title"] as? String ?? "",
                                     content: $0["content"] as? String ?? "")
                },
                events: events.map {
                    Summary.Event(title: $0["title"] as? String ?? "",
                                  date: $0["date"] as? String ?? "")
                }
            )
            return buildText(from: summary)
        }

        return JSONFormatter.pretty(from: cleaned)
    }

    private static func buildText(from summary: Summary) -> String {
        var lines: [String] = []
        for section in summary.sections {
            guard !section.title.isEmpty || !section.content.isEmpty else { continue }
            lines.append("\u{2022} \(section.title): \(section.content)")
        }

        if !summary.events.isEmpty {
            lines.append("")
            lines.append("Events:")
            let dfIn = ISO8601DateFormatter()
            let dfOut = DateFormatter(); dfOut.dateStyle = .medium
            for event in summary.events {
                let title = event.title
                let rawDate = event.date
                if let date = dfIn.date(from: rawDate) {
                    lines.append("- \(dfOut.string(from: date)): \(title)")
                } else {
                    lines.append("- \(rawDate): \(title)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
