import XCTest
@testable import CoreUtilitiesKit

final class JSONDiskStoreTests: XCTestCase {
    private struct Payload: Codable, Equatable, Sendable {
        let id: String
        let count: Int
    }

    func testSaveLoadAndClear() async {
        let store = JSONDiskStore<Payload>(
            filename: "json-disk-store-\(UUID().uuidString).json",
            directoryName: "CoreUtilitiesKitTests"
        )
        let value = Payload(id: "lesson", count: 3)

        _ = await store.saveNow(value)

        let loaded = await store.load()
        XCTAssertEqual(loaded, value)

        await store.clear()
        let cleared = await store.load()
        XCTAssertNil(cleared)
    }

    func testSaveNowDeduplicatesUnchangedPayload() async {
        let store = JSONDiskStore<Payload>(
            filename: "json-disk-store-\(UUID().uuidString).json",
            directoryName: "CoreUtilitiesKitTests"
        )
        let value = Payload(id: "lesson", count: 3)

        let firstWrite = await store.saveNow(value)
        let secondWrite = await store.saveNow(value)

        XCTAssertTrue(firstWrite)
        XCTAssertFalse(secondWrite)
    }

    func testFlushPendingSaveWaitsForDebouncedWrite() async {
        let store = JSONDiskStore<Payload>(
            filename: "json-disk-store-\(UUID().uuidString).json",
            directoryName: "CoreUtilitiesKitTests"
        )
        let value = Payload(id: "lesson", count: 9)

        await store.save(value, debounceNanoseconds: 50_000_000)
        await store.flushPendingSave()

        let loaded = await store.load()
        XCTAssertEqual(loaded, value)
    }

    func testStorageURLPointsToConfiguredDirectory() async {
        let directoryName = "CoreUtilitiesKitTests-\(UUID().uuidString)"
        let filename = "payload.json"
        let store = JSONDiskStore<Payload>(filename: filename, directoryName: directoryName)

        let url = await store.storageURL()
        XCTAssertEqual(url.lastPathComponent, filename)
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, directoryName)
    }
}
