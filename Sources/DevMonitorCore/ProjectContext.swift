import Foundation

public enum ManifestKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case packageJSON
    case cargoToml
    case goMod
    case pyproject
    case gemfile
    case swiftPackage
    case pomXML
    case composerJSON
    case mixExs

    public var fileName: String {
        switch self {
        case .packageJSON: return "package.json"
        case .cargoToml: return "Cargo.toml"
        case .goMod: return "go.mod"
        case .pyproject: return "pyproject.toml"
        case .gemfile: return "Gemfile"
        case .swiftPackage: return "Package.swift"
        case .pomXML: return "pom.xml"
        case .composerJSON: return "composer.json"
        case .mixExs: return "mix.exs"
        }
    }
}

public struct ProjectContext: Equatable, Hashable, Sendable {
    public var workingDirectory: String
    public var gitRoot: String?
    public var projectName: String?
    public var manifestKind: ManifestKind?
    public var manifestPath: String?

    public init(
        workingDirectory: String,
        gitRoot: String?,
        projectName: String?,
        manifestKind: ManifestKind?,
        manifestPath: String?
    ) {
        self.workingDirectory = workingDirectory
        self.gitRoot = gitRoot
        self.projectName = projectName
        self.manifestKind = manifestKind
        self.manifestPath = manifestPath
    }
}
