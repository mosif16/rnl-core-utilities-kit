import Foundation

#if canImport(os)
import os
#endif

/// Lightweight timing + signpost helper for end-to-end pipeline profiling.
///
/// Designed to be low overhead in release builds:
/// - In Release, only logs when a target threshold is exceeded.
/// - In Debug, can log all spans when `PERF_TRACE_ALL=1`.
public enum PerformanceTrace {
    private static let clock = ContinuousClock()

#if canImport(os)
    @available(iOS 15.0, macOS 12.0, *)
    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "CoreUtilitiesKit",
        category: "Performance"
    )
#endif

    private static var traceAll: Bool {
#if DEBUG
        if let raw = ProcessInfo.processInfo.environment["PERF_TRACE_ALL"]?.lowercased() {
            return ["1", "true", "yes", "on"].contains(raw)
        }
#endif
        return false
    }

    @discardableResult
    public static func measure<T>(
        _ name: StaticString,
        targetSeconds: Double? = nil,
        metadata: @autoclosure () -> String? = nil,
        operation: () throws -> T
    ) rethrows -> T {
        let start = clock.now
#if canImport(os)
        let state: OSSignpostIntervalState?
        if #available(iOS 15.0, macOS 12.0, *) {
            state = signposter.beginInterval(name)
        } else {
            state = nil
        }
#else
        let state: Any? = nil
#endif

        defer {
            let elapsed = start.duration(to: clock.now).seconds
#if canImport(os)
            if #available(iOS 15.0, macOS 12.0, *), let state {
                signposter.endInterval(name, state)
            }
#endif
            maybeLog(name, seconds: elapsed, targetSeconds: targetSeconds, metadata: metadata())
        }

        return try operation()
    }

    @discardableResult
    public static func measureAsync<T>(
        _ name: StaticString,
        targetSeconds: Double? = nil,
        metadata: @autoclosure () -> String? = nil,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = clock.now
#if canImport(os)
        let state: OSSignpostIntervalState?
        if #available(iOS 15.0, macOS 12.0, *) {
            state = signposter.beginInterval(name)
        } else {
            state = nil
        }
#else
        let state: Any? = nil
#endif

        defer {
            let elapsed = start.duration(to: clock.now).seconds
#if canImport(os)
            if #available(iOS 15.0, macOS 12.0, *), let state {
                signposter.endInterval(name, state)
            }
#endif
            maybeLog(name, seconds: elapsed, targetSeconds: targetSeconds, metadata: metadata())
        }

        return try await operation()
    }

    private static func maybeLog(_ name: StaticString, seconds: Double, targetSeconds: Double?, metadata: String?) {
        let exceeded: Bool = {
            guard let targetSeconds else { return true }
            return seconds >= targetSeconds
        }()

        guard traceAll || exceeded else { return }

        let ms = Int(seconds * 1000)
        let targetMs = targetSeconds.map { Int($0 * 1000) }
        let meta = metadata?.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = meta.map { " \($0)" } ?? ""
        let displayName = String(describing: name)

        if let targetMs {
            DiagnosticsLogger.log("[Perf] \(displayName) \(ms)ms target=\(targetMs)ms\(suffix)")
        } else {
            DiagnosticsLogger.log("[Perf] \(displayName) \(ms)ms\(suffix)")
        }
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
