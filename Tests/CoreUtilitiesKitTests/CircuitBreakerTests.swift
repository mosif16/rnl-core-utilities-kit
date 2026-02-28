import XCTest
@testable import CoreUtilitiesKit

final class CircuitBreakerTests: XCTestCase {
    private func makeDeterministicBreaker(baseBackoff: TimeInterval = 2.0) -> CircuitBreaker {
        let configuration = CircuitBreaker.Configuration(
            baseBackoffSeconds: baseBackoff,
            maxBackoffSeconds: 60.0,
            maxExponent: 6,
            jitterRange: 0...0
        )
        return CircuitBreaker(configuration: configuration)
    }

    func testInitialStateAllowsRequests() async {
        let breaker = makeDeterministicBreaker()
        let allowed = await breaker.allowRequest(host: "api.example.com")
        XCTAssertTrue(allowed)
    }

    func testFailureTripsBreakerForHost() async {
        let breaker = makeDeterministicBreaker()
        let host = "api.example.com"

        await breaker.recordFailure(host: host)

        let allowed = await breaker.allowRequest(host: host)
        XCTAssertFalse(allowed)
    }

    func testSuccessResetsBreaker() async {
        let breaker = makeDeterministicBreaker()
        let host = "api.example.com"

        await breaker.recordFailure(host: host)
        let deniedAfterFailure = await breaker.allowRequest(host: host)
        XCTAssertFalse(deniedAfterFailure)

        await breaker.recordSuccess(host: host)
        let allowedAfterSuccess = await breaker.allowRequest(host: host)
        XCTAssertTrue(allowedAfterSuccess)
    }

    func testHostsAreIndependent() async {
        let breaker = makeDeterministicBreaker()
        let hostA = "api-a.example.com"
        let hostB = "api-b.example.com"

        await breaker.recordFailure(host: hostA)

        let hostAAllowed = await breaker.allowRequest(host: hostA)
        let hostBAllowed = await breaker.allowRequest(host: hostB)
        XCTAssertFalse(hostAAllowed)
        XCTAssertTrue(hostBAllowed)
    }

    func testRetryAfterFollowsExponentialBackoffAndCapsAtMax() async {
        let config = CircuitBreaker.Configuration(
            baseBackoffSeconds: 1.0,
            maxBackoffSeconds: 4.0,
            maxExponent: 3,
            jitterRange: 0...0
        )
        let breaker = CircuitBreaker(configuration: config)
        let now = Date()
        let host = "api.example.com"

        await breaker.recordFailure(host: host, at: now)
        let retry1 = await breaker.retryAfter(host: host, at: now)
        XCTAssertNotNil(retry1)
        XCTAssertEqual(retry1 ?? -1, 1.0, accuracy: 0.0001)

        await breaker.recordFailure(host: host, at: now)
        let retry2 = await breaker.retryAfter(host: host, at: now)
        XCTAssertNotNil(retry2)
        XCTAssertEqual(retry2 ?? -1, 2.0, accuracy: 0.0001)

        await breaker.recordFailure(host: host, at: now)
        let retry3 = await breaker.retryAfter(host: host, at: now)
        XCTAssertNotNil(retry3)
        XCTAssertEqual(retry3 ?? -1, 4.0, accuracy: 0.0001)

        await breaker.recordFailure(host: host, at: now)
        let retry4 = await breaker.retryAfter(host: host, at: now)
        XCTAssertNotNil(retry4)
        XCTAssertEqual(retry4 ?? -1, 4.0, accuracy: 0.0001)
    }

    func testAllowRequestCanBeEvaluatedAtCustomTime() async {
        let breaker = makeDeterministicBreaker(baseBackoff: 2.0)
        let now = Date()
        let host = "api.example.com"

        await breaker.recordFailure(host: host, at: now)

        let allowedImmediately = await breaker.allowRequest(host: host, at: now)
        XCTAssertFalse(allowedImmediately)

        let allowedAfterBackoff = await breaker.allowRequest(host: host, at: now.addingTimeInterval(2.0))
        XCTAssertTrue(allowedAfterBackoff)
    }

    func testResetAndResetAllClearState() async {
        let breaker = makeDeterministicBreaker()
        await breaker.recordFailure(host: "a.example.com")
        await breaker.recordFailure(host: "b.example.com")

        let initialA = await breaker.failureCount(for: "a.example.com")
        let initialB = await breaker.failureCount(for: "b.example.com")
        XCTAssertEqual(initialA, 1)
        XCTAssertEqual(initialB, 1)

        await breaker.reset(host: "a.example.com")
        let afterResetA = await breaker.failureCount(for: "a.example.com")
        let afterResetB = await breaker.failureCount(for: "b.example.com")
        XCTAssertEqual(afterResetA, 0)
        XCTAssertEqual(afterResetB, 1)

        await breaker.resetAll()
        let finalB = await breaker.failureCount(for: "b.example.com")
        XCTAssertEqual(finalB, 0)
    }
}
