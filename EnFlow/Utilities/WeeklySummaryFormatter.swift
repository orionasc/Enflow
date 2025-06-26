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

        guard let data = cleaned.data(using: .utf8),
              let summary = try? JSONDecoder().decode(Summary.self, from: data) else {
            return JSONFormatter.pretty(from: cleaned)
        }

        var lines: [String] = []
        for section in summary.sections {
            lines.append("\u{2022} \(section.title): \(section.content)")
        }

        if !summary.events.isEmpty {
            lines.append("")
            lines.append("Events:")
            let dfIn = ISO8601DateFormatter()
            let dfOut = DateFormatter(); dfOut.dateStyle = .medium
            for event in summary.events {
                if let date = dfIn.date(from: event.date) {
                    lines.append("- \(dfOut.string(from: date)): \(event.title)")
                } else {
                    lines.append("- \(event.date): \(event.title)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
