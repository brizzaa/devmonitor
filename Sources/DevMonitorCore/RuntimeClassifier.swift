import Foundation

public struct RuntimeClassifier: Sendable {
    public init() {}

    public func classify(name: String, command: String) -> DevRuntime {
        let base = normalized(name)
        let commandText = command.lowercased()

        if isDocker(base) { return .docker }
        if base == "postgres" || base == "postmaster" { return .postgres }
        if base == "redis" || base == "redis-server" || base == "redis-sentinel" { return .redis }
        if base == "mysqld" || base == "mariadbd" { return .mysql }
        if base == "mongod" || base == "mongos" { return .mongo }
        if base == "nginx" { return .nginx }
        if isPHP(base) { return .php }
        if base == "beam.smp" || base == "erl" || base == "elixir" || commandText.contains("beam.smp") {
            return .beam
        }
        if base == "dotnet" { return .dotnet }
        if base == "kubelet" || base == "kubectl" || base == "minikube" || base == "k3s" {
            return .kubernetes
        }
        if nodeNames.contains(base) { return .node }
        if base == "bun" { return .bun }
        if base == "deno" { return .deno }
        if isPython(base) { return .python }
        if rubyNames.contains(base) { return .ruby }
        if base == "java" || base == "javaw" { return .java }
        if base == "go" || base == "dlv" || base.hasPrefix("__debug_bin") { return .go }
        if base == "cargo" || base == "rustc" || base == "rust-analyzer" { return .rust }
        if base == "swift" || base == "swift-frontend" || base == "swift-build" || base == "sourcekit-lsp" {
            return .swift
        }
        if commandText.contains("go-build") { return .go }
        if commandText.contains("/target/debug/") || commandText.contains("/target/release/") { return .rust }
        if commandText.contains("/.build/") { return .swift }
        return .unknown
    }

    private func normalized(_ name: String) -> String {
        var value = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("-"), value.count > 1 { value.removeFirst() }
        if value.hasSuffix(":"), value.count > 1 { value.removeLast() }
        return value
    }

    private func isDocker(_ base: String) -> Bool {
        base.contains("docker") || base == "containerd" || base == "dockerd" || base == "colima"
    }

    private func isPHP(_ base: String) -> Bool {
        base == "php" || base.hasPrefix("php-fpm") || base.range(of: #"^php\d"#, options: .regularExpression) != nil
    }

    private func isPython(_ base: String) -> Bool {
        base.hasPrefix("python")
            || base == "gunicorn"
            || base == "uvicorn"
            || base == "uwsgi"
            || base == "celery"
    }

    private var nodeNames: Set<String> {
        ["node", "nodejs", "npm", "npx", "pnpm", "yarn", "yarnpkg", "next-server", "ts-node", "tsx"]
    }

    private var rubyNames: Set<String> {
        ["ruby", "rails", "puma", "sidekiq", "bundle", "bundler", "rake", "irb"]
    }
}
