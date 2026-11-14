import Foundation

public struct DockerContainer: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var image: String
    public var status: String
    public var ports: String
    public var state: String

    public init(id: String, name: String, image: String, status: String, ports: String, state: String) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
        self.state = state
    }
}

public struct DockerPsParser: Sendable {
    public init() {}

    /// One JSON object per line, as produced by `docker ps --format '{{json .}}'`.
    public func parse(_ output: String) -> [DockerContainer] {
        var containers: [DockerContainer] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let id = stringField(object, "ID") ?? stringField(object, "Id") ?? ""
            guard !id.isEmpty else { continue }
            containers.append(
                DockerContainer(
                    id: id,
                    name: stringField(object, "Names") ?? stringField(object, "Name") ?? id,
                    image: stringField(object, "Image") ?? "",
                    status: stringField(object, "Status") ?? "",
                    ports: stringField(object, "Ports") ?? "",
                    state: stringField(object, "State") ?? ""
                )
            )
        }
        return containers
    }

    private func stringField(_ object: [String: Any], _ key: String) -> String? {
        guard let value = object[key] else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }
}

public struct DockerLoadResult: Equatable, Sendable {
    public var containers: [DockerContainer]
    public var available: Bool
    public var warning: String?

    public init(containers: [DockerContainer], available: Bool, warning: String?) {
        self.containers = containers
        self.available = available
        self.warning = warning
    }

    public static let unavailable = DockerLoadResult(containers: [], available: false, warning: nil)
}

public struct DockerSnapshotLoader: Sendable {
    public var runner: any CommandRunning
    public var executable: String
    public var arguments: [String]

    public init(
        runner: any CommandRunning,
        executable: String = "/usr/bin/env",
        arguments: [String] = ["docker", "ps", "--format", "{{json .}}"]
    ) {
        self.runner = runner
        self.executable = executable
        self.arguments = arguments
    }

    public func load() -> DockerLoadResult {
        let output: CommandOutput
        do {
            output = try runner.run(executable: executable, arguments: arguments)
        } catch {
            return .unavailable
        }
        let containers = DockerPsParser().parse(output.stdout)
        if output.status == 127 {
            return .unavailable
        }
        if output.status == 0 {
            return DockerLoadResult(containers: containers, available: true, warning: nil)
        }
        let detail = output.stderr.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let warning = detail.isEmpty ? "docker ps exited with status \(output.status)." : detail
        return DockerLoadResult(containers: containers, available: true, warning: warning)
    }
}
