import XCTest
@testable import CoreUtilitiesKit

final class TextSanitizerTests: XCTestCase {
    func testDenoiseRemovesNoisePatterns() {
        let input = """
        00:12 Speaker 1: Um, welcome everyone.
        [Applause]
        This video is sponsored by Example Co.
        You know this is kind of useful.
        You know this is kind of useful.
        You know this is kind of useful.
        Core concept: spaced repetition improves recall.
        """

        let output = TextSanitizer.denoise(input)

        XCTAssertFalse(output.contains("00:12"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("applause"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("you know"))
        XCTAssertTrue(output.contains("Core concept"))
    }

    func testDenoiseKeepsMeaningfulContent() {
        let input = """
        Teacher: Retrieval practice strengthens memory.
        Student: We should test ourselves regularly.
        """

        let output = TextSanitizer.denoise(input)

        XCTAssertTrue(output.localizedCaseInsensitiveContains("Retrieval practice"))
        XCTAssertTrue(output.localizedCaseInsensitiveContains("test ourselves regularly"))
    }
}
