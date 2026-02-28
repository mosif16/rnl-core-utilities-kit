import Foundation

/// Simple host-level circuit breaker with exponential backoff.
public actor CircuitBreaker {
    public struct Configuration: Sendable, Equatable {
        public let baseBackoffSeconds: TimeInterval
        public let maxBackoffSeconds: TimeInterval
        public let maxExponent: Int
        public let jitterRange: ClosedRange<Double>

        public init(
            baseBackoffSeconds: TimeInterval = 2.0,
            maxBackoffSeconds: TimeInterval = 60.0,
            maxExponent: Int = 6,
            jitterRange: ClosedRange<Double> = 0...0.5
        ) {
            precondition(baseBackoffSeconds > 0, "baseBackoffSeconds must be > 0")
            precondition(maxBackoffSeconds >= baseBackoffSeconds, "maxBackoffSeconds must be >= baseBackoffSeconds")
            precondition(maxExponent >= 0, "maxExponent must be >= 0")
            precondition(jitterRange.lowerBound >= 0, "jitterRange lower bound must be >= 0")
            precondition(jitterRange.lowerBound <= jitterRange.upperBound, "jitterRange must be a valid range")

            self.baseBackoffSeconds = baseBackoffSeconds
            self.maxBackoffSeconds = maxBackoffSeconds
            self.maxExponent = maxExponent
            self.jitterRange = jitterRange
        }

        public static let `default` = Configuration()
    }

    public static let shared = CircuitBreaker()

    private struct State {
        var failures: Int = 0
        var openUntil: Date? = nil
    }

    private let configuration: Configuration
    private var states: [String: State] = [:]

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Returns whether a request to `host` should be allowed now.
    public func allowRequest(host: String, at now: Date = Date()) -> Bool {
        if let s = states[host], let until = s.openUntil {
            return now >= until
        }
        return true
    }

    /// Records a successful call, closing the breaker.
    public func recordSuccess(host: String) {
        states[host] = State(failures: 0, openUntil: nil)
    }

    /// Records a failure and opens the breaker with exponential backoff.
    public func recordFailure(host: String, at now: Date = Date()) {
        var s = states[host] ?? State()
        s.failures += 1
        let seconds = backoffSeconds(forFailures: s.failures)
        let jitter = randomJitter(in: configuration.jitterRange)
        s.openUntil = now.addingTimeInterval(seconds + jitter)
        states[host] = s
    }

    /// Returns the number of consecutive failures tracked for `host`.
    public func failureCount(for host: String) -> Int {
        states[host]?.failures ?? 0
    }

    /// Returns the remaining wait time (in seconds) before `host` is allowed again.
    public func retryAfter(host: String, at now: Date = Date()) -> TimeInterval? {
        guard let state = states[host], let until = state.openUntil, until > now else {
            return nil
        }
        return until.timeIntervalSince(now)
    }

    /// Clears tracked state for a single host.
    public func reset(host: String) {
        states.removeValue(forKey: host)
    }

    /// Clears tracked state for all hosts.
    public func resetAll() {
        states.removeAll(keepingCapacity: true)
    }

    private func backoffSeconds(forFailures failures: Int) -> TimeInterval {
        let exponent = max(0, min(configuration.maxExponent, failures - 1))
        let raw = configuration.baseBackoffSeconds * pow(2.0, Double(exponent))
        return min(raw, configuration.maxBackoffSeconds)
    }

    private func randomJitter(in range: ClosedRange<Double>) -> Double {
        if range.lowerBound == range.upperBound {
            return range.lowerBound
        }
        return Double.random(in: range)
    }
}
