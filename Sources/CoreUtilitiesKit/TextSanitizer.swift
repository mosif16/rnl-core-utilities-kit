import Foundation

/// Lightweight, conservative text denoiser for study material before sending to LLMs.
/// - Removes obvious noise: timestamps, speaker tags, table blocks, repeated lines,
///   disclaimers/sponsor lines, and non‑content stage directions (e.g., [Applause]).
/// - Avoids aggressive rewriting; intended to reduce tokens while preserving meaning.
public struct TextSanitizer {
    public static func denoise(_ input: String) -> String {
        // Normalize newlines
        let unified = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = unified.components(separatedBy: "\n")

        // Precompute tableish flags per line (markdown/ascii tables)
        let isTableish: [Bool] = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return false }
            // markdown tables: multiple pipes or header separators
            let pipeCount = trimmed.filter { $0 == "|" }.count
            if pipeCount >= 2 { return true }
            if trimmed.range(of: #"^[|:+\-\s]+$"#, options: .regularExpression) != nil { return true }
            // ascii tables (borders with +---+)
            if trimmed.range(of: #"^[+\-]+[+\-\s]+$"#, options: .regularExpression) != nil { return true }
            return false
        }

        // Repeated line tracking (normalized)
        var seenCounts: [String: Int] = [:]

        // Patterns
        let timestampPrefix = try? NSRegularExpression(pattern: #"^\s*\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*[-–—:]?\s*"#, options: [.caseInsensitive])
        let speakerPrefix = try? NSRegularExpression(
            pattern: #"^\s*(Speaker|Host|Narrator|Interviewer|Interviewee|Student|Teacher|Prof(?:essor)?|Instructor|Voice|Male|Female)\s*\d*\s*:\s*"#,
            options: [.caseInsensitive]
        )
        let stageDirection = try? NSRegularExpression(pattern: #"^\s*\[?(applause|music|laughter|silence|inaudible)\]?\s*$"#, options: [.caseInsensitive])

        // Disclaimers / sponsor / CTA lines (common variants)
        let disclaimerPatterns: [NSRegularExpression] = [
            try? NSRegularExpression(pattern: #"^\s*disclaimer[:\n\r\t\s]"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"not (financial|medical|legal) advice"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"for (educational|informational) purposes only"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"^\s*sponsored by"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"\bsubscribe\b|\blike and subscribe\b|\bfollow (us|me)\b|\bpatreon\b|\bmerch\b|link in (bio|description)"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"^\s*copyright"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"^\s*terms? and conditions"#, options: [.caseInsensitive])
        ].compactMap { $0 }

        var cleaned: [String] = []
        cleaned.reserveCapacity(lines.count)
        for i in 0..<lines.count {
            var line = lines[i]
            var trimmed = line.trimmingCharacters(in: .whitespaces)

            // Drop table blocks: only if neighbor is also tableish to avoid false positives
            if isTableish[i] {
                let prevIs = i > 0 ? isTableish[i - 1] : false
                let nextIs = i + 1 < isTableish.count ? isTableish[i + 1] : false
                if prevIs || nextIs { continue }
            }

            // Strip timestamps and speaker tags from line start
            if let rx = timestampPrefix { line = rx.stringByReplacingMatches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count), withTemplate: "") }
            if let rx = speakerPrefix { line = rx.stringByReplacingMatches(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count), withTemplate: "") }
            trimmed = line.trimmingCharacters(in: .whitespaces)

            // Drop pure stage direction markers
            if let rx = stageDirection, rx.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil { continue }

            // Drop obvious disclaimer/CTA lines
            var dropLine = false
            for rx in disclaimerPatterns {
                if rx.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
                    dropLine = true; break
                }
            }
            if dropLine { continue }

            // Skip consecutive duplicate lines and clamp total repeats
            let norm = trimmed.lowercased()
            if let prev = cleaned.last, prev.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == norm { continue }
            let count = (seenCounts[norm] ?? 0) + 1
            seenCounts[norm] = count
            if count > 2 { continue }

            cleaned.append(line)
        }

        var out = cleaned.joined(separator: "\n")

        // Remove common filler phrases conservatively (word boundaries)
        let fillerPatterns: [NSRegularExpression] = [
            try? NSRegularExpression(pattern: #"\b(u+h+|um+|er+|ah+)\b"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"\b(you know|i mean)\b[, ]*"#, options: [.caseInsensitive]),
            try? NSRegularExpression(pattern: #"\b(kind of|sort of)\b[, ]*"#, options: [.caseInsensitive])
        ].compactMap { $0 }
        for rx in fillerPatterns {
            out = rx.stringByReplacingMatches(in: out, options: [], range: NSRange(location: 0, length: out.utf16.count), withTemplate: "")
        }

        // Collapse excessive spaces and blank lines
        out = out.replacingOccurrences(of: "\t", with: " ")
        // Replace 3+ newlines with 2
        while out.contains("\n\n\n") { out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        // Normalize spaces around punctuation
        out = out.replacingOccurrences(of: "  ", with: " ")

        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
