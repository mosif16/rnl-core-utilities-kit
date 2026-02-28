import Foundation

/// Small helper actor to perform synchronous file I/O off the main actor.
public actor FileIO {
    public static let shared = FileIO()

    public init() {}

    public func readString(from url: URL, encoding: String.Encoding = .utf8) throws -> String {
        try String(contentsOf: url, encoding: encoding)
    }
}
