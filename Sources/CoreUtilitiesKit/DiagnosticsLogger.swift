import Foundation

public enum DiagnosticsLogger {
    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let resolvedMessage = redacted(message())
        #if DEBUG
        print("[Diagnostics] \(resolvedMessage)")
        #else
        NSLog("[Diagnostics] %@", resolvedMessage)
        #endif
    }

    public static var isEnabled: Bool {
#if DEBUG
        return envToggle("CORE_UTILS_DIAGNOSTICS", defaultValue: true)
#else
        return envToggle("CORE_UTILS_DIAGNOSTICS", defaultValue: false)
#endif
    }

    /// Returns a redacted copy of the message suitable for safe logging.
    public static func redacted(_ message: String) -> String {
        redactSensitiveData(message)
    }

    // MARK: - Sensitive Data Redaction

    private static func redactSensitiveData(_ message: String) -> String {
        var result = message

        // Redact email addresses
        if let emailRegex = try? NSRegularExpression(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}") {
            result = emailRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "[REDACTED_EMAIL]")
        }

        // Redact Bearer tokens
        if let bearerRegex = try? NSRegularExpression(pattern: "Bearer\\s+[A-Za-z0-9_\\-\\.]+") {
            result = bearerRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "Bearer [REDACTED]")
        }

        // Redact API keys (sk-... or key-... patterns)
        if let apiKeyRegex = try? NSRegularExpression(pattern: "(?:sk|key|api[_-]?key)[_-][A-Za-z0-9]{16,}") {
            result = apiKeyRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "[REDACTED_KEY]")
        }

        return result
    }

    private static func envToggle(_ key: String, defaultValue: Bool) -> Bool {
        guard let raw = ProcessInfo.processInfo.environment[key]?.lowercased() else {
            return defaultValue
        }
        if ["1", "true", "yes", "on"].contains(raw) { return true }
        if ["0", "false", "no", "off"].contains(raw) { return false }
        return defaultValue
    }
}
