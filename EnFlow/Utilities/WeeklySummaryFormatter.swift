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
            .replacingOccurrences(of: "```yaml", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Trim to YAML block if extra text surrounds it
        if let range = cleaned.range(of: "sections:") ?? cleaned.range(of: "events:") {
            cleaned = String(cleaned[range.lowerBound...])
        }

        if let summary = parseYAML(cleaned) {
            return buildText(from: summary)
        }

        return cleaned
    }

    /// Very small YAML parser for the limited summary format.
    private static func parseYAML(_ text: String) -> Summary? {
        var sections: [Summary.Section] = []
        var events: [Summary.Event] = []

        enum Mode { case none, sections, events }
        var mode: Mode = .none
        var currentTitle: String = ""

        func strip(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("\"") && t.hasSuffix("\"") { t.removeFirst(); t.removeLast() }
            return t
        }

        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("sections:") { mode = .sections; continue }
            if line.hasPrefix("events:") { mode = .events; continue }
            if line.hasPrefix("- title:") {
                currentTitle = strip(String(line.dropFirst(8)))
                continue
            }
            if line.hasPrefix("content:") && mode == .sections {
                let content = strip(String(line.dropFirst(8)))
                sections.append(Summary.Section(title: currentTitle, content: content))
                continue
            }
            if line.hasPrefix("date:") && mode == .events {
                let date = strip(String(line.dropFirst(5)))
                events.append(Summary.Event(title: currentTitle, date: date))
                continue
            }
        }

        guard !sections.isEmpty || !events.isEmpty else { return nil }
        return Summary(sections: sections, events: events)
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
