import XCTest
@testable import CoreUtilitiesKit

final class DiagnosticsLoggerTests: XCTestCase {
    func testLogDoesNotCrash() {
        DiagnosticsLogger.log("General diagnostics message")
    }

    func testSensitivePatternsDoNotCrashLogger() {
        DiagnosticsLogger.log("User email: test@example.com")
        DiagnosticsLogger.log("Authorization: Bearer sk-abc123def456ghi789jkl012")
        DiagnosticsLogger.log("Using key: sk-AAAAAAAAAAAAAAAA")
        DiagnosticsLogger.log("api_key-BBBBBBBBBBBBBBBB")
    }

    func testDiagnosticsToggleIsReadable() {
        _ = DiagnosticsLogger.isEnabled
    }

    func testRedactedMasksSensitiveData() {
        let raw = "user=test@example.com token=Bearer sk-abc123456789 key=api_key-ABCDEFGHIJKLMNOP"
        let sanitized = DiagnosticsLogger.redacted(raw)

        XCTAssertFalse(sanitized.contains("test@example.com"))
        XCTAssertFalse(sanitized.contains("sk-abc123456789"))
        XCTAssertFalse(sanitized.contains("api_key-ABCDEFGHIJKLMNOP"))
        XCTAssertTrue(sanitized.contains("[REDACTED_EMAIL]"))
        XCTAssertTrue(sanitized.contains("Bearer [REDACTED]"))
        XCTAssertTrue(sanitized.contains("[REDACTED_KEY]"))
    }
}
