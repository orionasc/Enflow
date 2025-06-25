import Foundation

enum JSONFormatter {
    /// Prettify a raw string into formatted JSON. Removes common GPT wrappers
    /// like markdown code fences and smart quotes. If parsing fails the cleaned
    /// string is returned unchanged.
    static func pretty(from raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize curly quotes that GPT might emit
        cleaned = cleaned
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")

        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return cleaned
        }
        return pretty
    }
}
