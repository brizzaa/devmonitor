import Foundation

public struct SnapshotLoadResult: Equatable, Sendable {
    public var processes: [DeveloperProcess]
    public var warnings: [String]

    public init(processes: [DeveloperProcess], warnings: [String]) {
        self.processes = processes
        self.warnings = warnings
    }
}

public struct LiveSnapshotLoader: Sendable {
    private let runner: any CommandRunning
    private let detector: ProjectDetector
    private let assembler: SnapshotAssembler
    public var includeEstablished: Bool
    public var includeUDP: Bool

    public init(
        runner: any CommandRunning,
        detector: ProjectDetector,
        assembler: SnapshotAssembler = SnapshotAssembler(),
        includeEstablished: Bool = true,
        includeUDP: Bool = true
    ) {
        self.runner = runner
        self.detector = detector
        self.assembler = assembler
        self.includeEstablished = includeEstablished
        self.includeUDP = includeUDP
    }

    public func load(now: Date = Date()) -> SnapshotLoadResult {
        var warnings: [String] = []
        let psOutput = capture(
            label: "ps",
            executable: ProcessCommands.psExecutable,
            arguments: ProcessCommands.psArguments,
            allowStatusOne: false,
            warnings: &warnings
        )
        guard !warnings.contains(where: { $0.hasPrefix("ps ") }) || !psOutput.isEmpty else {
            return SnapshotLoadResult(processes: [], warnings: warnings)
        }
        if psOutput.isEmpty && warnings.contains(where: { $0.hasPrefix("ps ") }) {
            return SnapshotLoadResult(processes: [], warnings: warnings)
        }

        let processes = PSParser().parse(psOutput, now: now)
        if processes.isEmpty && !psOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("ps returned output that DevMonitor could not parse.")
        }

        var ports: [PortBinding] = []
        let listen = capture(
            label: "lsof (listening TCP)",
            executable: ProcessCommands.lsofExecutable,
            arguments: ProcessCommands.listenArguments,
            allowStatusOne: true,
            warnings: &warnings
        )
        ports.append(contentsOf: LsofParser().parse(listen))

        if includeEstablished {
            let established = capture(
                label: "lsof (established TCP)",
                executable: ProcessCommands.lsofExecutable,
                arguments: ProcessCommands.establishedArguments,
                allowStatusOne: true,
                warnings: &warnings
            )
            ports.append(contentsOf: LsofParser().parse(established))
        }
        if includeUDP {
            let udp = capture(
                label: "lsof (UDP)",
                executable: ProcessCommands.lsofExecutable,
                arguments: ProcessCommands.udpArguments,
                allowStatusOne: true,
                warnings: &warnings
            )
            ports.append(contentsOf: LsofParser().parse(udp))
        }

        let cwdOutput = capture(
            label: "lsof (working directories)",
            executable: ProcessCommands.lsofExecutable,
            arguments: ProcessCommands.cwdArguments,
            allowStatusOne: true,
            warnings: &warnings
        )
        let directories = CwdParser().parse(cwdOutput)
        var projects: [String: ProjectContext] = [:]
        for cwd in Set(directories.values) {
            projects[cwd] = detector.detect(workingDirectory: cwd)
        }

        let assembled = assembler.assemble(
            processes: processes,
            ports: ports,
            workingDirectories: directories,
            projects: projects
        )
        return SnapshotLoadResult(processes: assembled, warnings: warnings)
    }

    private func capture(
        label: String,
        executable: String,
        arguments: [String],
        allowStatusOne: Bool,
        warnings: inout [String]
    ) -> String {
        let output: CommandOutput
        do {
            output = try runner.run(executable: executable, arguments: arguments)
        } catch {
            warnings.append("\(label) could not be run (\(executable)): \(error)")
            return ""
        }
        let acceptable = output.status == 0 || (allowStatusOne && output.status == 1)
        if acceptable { return output.stdout }
        let detail = firstLine(output.stderr)
        if output.stdout.isEmpty {
            warnings.append("\(label) exited with status \(output.status). \(detail)".trimmingCharacters(in: .whitespaces))
            return ""
        }
        warnings.append("\(label) exited with status \(output.status); showing partial output.")
        return output.stdout
    }

    private func firstLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if line.count > 240 { return String(line.prefix(240)) + "…" }
        return line
    }
}
