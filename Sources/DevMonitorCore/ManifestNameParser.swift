import Foundation

public enum ManifestNameParser {
    public static func name(kind: ManifestKind, contents: String, directory: String) -> String? {
        let parsed: String?
        switch kind {
        case .packageJSON:
            parsed = jsonName(contents)
        case .cargoToml:
            parsed = cargoName(contents)
        case .goMod:
            parsed = goModuleName(contents)
        case .pyproject:
            parsed = pyprojectName(contents)
        case .gemfile:
            parsed = PathNormalizer.basename(directory)
        case .swiftPackage:
            parsed = swiftPackageName(contents)
        case .pomXML:
            parsed = pomArtifactId(contents)
        case .composerJSON:
            parsed = jsonName(contents)
        case .mixExs:
            parsed = mixAppName(contents)
        }
        guard let parsed else {
            return kind == .gemfile ? PathNormalizer.basename(directory) : nil
        }
        let trimmed = parsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func jsonName(_ contents: String) -> String? {
        let text = stripBOM(contents)
        if let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = object["name"] as? String,
           !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return firstCapture(#""name"\s*:\s*"([^"]+)""#, in: text)
    }

    public static func cargoName(_ contents: String) -> String? {
        guard let body = section("[package]", in: contents) else { return nil }
        return tomlString("name", in: body)
    }

    public static func goModuleName(_ contents: String) -> String? {
        for raw in contents.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("module ") else { continue }
            let rest = line.dropFirst("module ".count)
            let path = rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
            let cleaned = path.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }
            return goPackageName(from: cleaned)
        }
        return nil
    }

    public static func pyprojectName(_ contents: String) -> String? {
        if let body = section("[project]", in: contents), let name = tomlString("name", in: body) {
            return name
        }
        if let body = section("[tool.poetry]", in: contents), let name = tomlString("name", in: body) {
            return name
        }
        return nil
    }

    public static func swiftPackageName(_ contents: String) -> String? {
        firstCapture(#"name\s*:\s*"([^"]+)""#, in: contents)
    }

    public static func pomArtifactId(_ contents: String) -> String? {
        let withoutParent = replacing(#"<parent>\s*[\s\S]*?</parent>"#, in: contents, with: "")
        return firstCapture(#"<artifactId>\s*([^<]+?)\s*</artifactId>"#, in: withoutParent)
    }

    public static func mixAppName(_ contents: String) -> String? {
        firstCapture(#"app:\s*:([A-Za-z0-9_]+)"#, in: contents)
    }

    static func goPackageName(from modulePath: String) -> String {
        let parts = modulePath.split(separator: "/").map(String.init)
        guard var last = parts.last else { return modulePath }
        if parts.count >= 2, last.range(of: #"^v[0-9]+$"#, options: .regularExpression) != nil {
            last = parts[parts.count - 2]
        }
        return last
    }

    private static func section(_ header: String, in contents: String) -> String? {
        var collecting = false
        var lines: [String] = []
        for raw in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                if collecting { break }
                if trimmed == header { collecting = true }
                continue
            }
            if collecting { lines.append(line) }
        }
        guard collecting else { return nil }
        return lines.joined(separator: "\n")
    }

    private static func tomlString(_ key: String, in body: String) -> String? {
        for raw in body.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(key) else { continue }
            let afterKey = line.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
            guard afterKey.hasPrefix("=") else { continue }
            var value = afterKey.dropFirst().trimmingCharacters(in: .whitespaces)
            if let hash = value.firstIndex(of: "#") {
                value = value[..<hash].trimmingCharacters(in: .whitespaces)
            }
            if value.count >= 2 {
                let quote = value.first
                if (quote == "\"" || quote == "'"), value.last == quote {
                    return String(value.dropFirst().dropLast())
                }
            }
        }
        return nil
    }

    private static func stripBOM(_ contents: String) -> String {
        contents.hasPrefix("\u{feff}") ? String(contents.dropFirst()) : contents
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capture])
    }

    private static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
