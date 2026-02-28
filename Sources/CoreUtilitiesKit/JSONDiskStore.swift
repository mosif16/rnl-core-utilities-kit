import Foundation

/// Lightweight, file-backed JSON store that saves and loads codable values off the main actor.
/// Writes are debounced and deduplicated to avoid unnecessary disk I/O churn.
public actor JSONDiskStore<Value: Codable & Sendable> {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var lastSavedData: Data?
    private var pendingSave: Task<Void, Never>?

    public init(filename: String, directoryName: String = "CoreUtilitiesKitData") {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(filename)
    }

    /// Load the value from disk if it exists.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        lastSavedData = data
        return try? decoder.decode(Value.self, from: data)
    }

    /// Persist the value to disk, coalescing rapid callers into a single write.
    public func save(_ value: Value, encodedData: Data? = nil, debounceNanoseconds: UInt64 = 250_000_000) {
        pendingSave?.cancel()
        pendingSave = Task { [value, encodedData, debounceNanoseconds] in
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            _ = self.saveNow(value, encodedData: encodedData)
        }
    }

    /// Persist immediately and return whether a write occurred (`false` means deduplicated or failed).
    @discardableResult
    public func saveNow(_ value: Value, encodedData: Data? = nil) -> Bool {
        pendingSave?.cancel()
        pendingSave = nil

        do {
            let data = try encodedData ?? encoder.encode(value)
            guard data != lastSavedData else { return false }
            try data.write(to: url, options: [.atomic])
            lastSavedData = data
            return true
        } catch {
            DiagnosticsLogger.log("[JSONDiskStore] Failed to save \(Value.self): \(error.localizedDescription)")
            return false
        }
    }

    /// Wait for the currently scheduled debounced save (if any) to finish.
    public func flushPendingSave() async {
        await pendingSave?.value
    }

    /// Exposes the underlying storage URL for diagnostics and integration checks.
    public func storageURL() -> URL {
        url
    }

    /// Remove the stored value.
    public func clear() {
        pendingSave?.cancel()
        pendingSave = nil
        lastSavedData = nil
        try? FileManager.default.removeItem(at: url)
    }
}
