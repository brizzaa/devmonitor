import Foundation

public enum PathNormalizer {
    public static func normalize(_ path: String) -> String {
        let isAbsolute = path.hasPrefix("/")
        var parts: [String] = []
        for raw in path.split(separator: "/", omittingEmptySubsequences: true) {
            let part = String(raw)
            if part == "." { continue }
            if part == ".." {
                if let last = parts.last, last != ".." {
                    parts.removeLast()
                } else if !isAbsolute {
                    parts.append("..")
                }
                continue
            }
            parts.append(part)
        }
        if parts.isEmpty { return isAbsolute ? "/" : "." }
        return (isAbsolute ? "/" : "") + parts.joined(separator: "/")
    }

    public static func parent(of path: String) -> String? {
        let normalized = normalize(path)
        if normalized == "/" || normalized == "." { return nil }
        guard let slash = normalized.lastIndex(of: "/") else { return nil }
        if slash == normalized.startIndex { return "/" }
        return String(normalized[..<slash])
    }

    /// The directory itself, then each parent, stopping at `/`.
    public static func ancestors(of path: String) -> [String] {
        var current = normalize(path)
        var chain: [String] = []
        while true {
            chain.append(current)
            guard let next = parent(of: current) else { break }
            current = next
        }
        return chain
    }

    public static func basename(_ path: String) -> String {
        let normalized = normalize(path)
        if normalized == "/" { return "/" }
        guard let slash = normalized.lastIndex(of: "/") else { return normalized }
        return String(normalized[normalized.index(after: slash)...])
    }

    public static func joining(_ directory: String, _ name: String) -> String {
        if directory == "/" { return "/" + name }
        return directory + "/" + name
    }
}
