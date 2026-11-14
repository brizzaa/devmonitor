import Foundation

public protocol FileSystemProbe: Sendable {
    func entryExists(at path: String) -> Bool
    func read(at path: String) -> String?
}

public struct LocalFileSystem: FileSystemProbe, Sendable {
    public init() {}

    public func entryExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// Reads at most 256 KB. Manifests we care about are far smaller; this
    /// keeps a huge accidental file from stalling a refresh.
    public func read(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 256 * 1024)
        return String(data: data, encoding: .utf8)
    }
}
