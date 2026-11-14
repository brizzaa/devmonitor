import Foundation

/// A recognised developer runtime. `.unknown` is everything else, including
/// ordinary macOS services, and is what "hide system processes" leans on
/// together with `SystemProcessHeuristic`.
public enum DevRuntime: String, Equatable, Hashable, Sendable, CaseIterable {
    case node
    case bun
    case deno
    case python
    case ruby
    case java
    case go
    case rust
    case swift
    case docker
    case postgres
    case redis
    case mysql
    case mongo
    case nginx
    case php
    case beam
    case dotnet
    case kubernetes
    case unknown

    public var isDeveloperFacing: Bool { self != .unknown }

    public var label: String {
        switch self {
        case .node: return "Node"
        case .bun: return "Bun"
        case .deno: return "Deno"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .go: return "Go"
        case .rust: return "Rust"
        case .swift: return "Swift"
        case .docker: return "Docker"
        case .postgres: return "Postgres"
        case .redis: return "Redis"
        case .mysql: return "MySQL"
        case .mongo: return "MongoDB"
        case .nginx: return "nginx"
        case .php: return "PHP"
        case .beam: return "BEAM"
        case .dotnet: return ".NET"
        case .kubernetes: return "Kubernetes"
        case .unknown: return "Other"
        }
    }
}
