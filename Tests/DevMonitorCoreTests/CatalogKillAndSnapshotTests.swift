import XCTest
@testable import DevMonitorCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

final class ProcessCatalogTests: XCTestCase {
    private let catalog = ProcessCatalog()

    private func sample() -> [DeveloperProcess] {
        let api = ProjectContext(workingDirectory: "/repo/api", gitRoot: "/repo", projectName: "api", manifestKind: .packageJSON, manifestPath: "/repo/api/package.json")
        let zebra = ProjectContext(workingDirectory: "/zebra", gitRoot: "/zebra", projectName: "Zebra", manifestKind: nil, manifestPath: nil)
        return [
            Fixtures.developed(
                Fixtures.process(pid: 2, cpu: 10, command: "node server.js --port 3000", name: "node"),
                ports: [Fixtures.port(pid: 2, localPort: 3000)],
                workingDirectory: "/repo/api",
                project: api,
                parents: ParentChain(ancestors: [], links: [], launcher: .cursor, summary: "Cursor → zsh"),
                runtime: .node
            ),
            Fixtures.developed(
                Fixtures.process(pid: 5, user: "root", cpu: 10, rssKB: 2048, command: "/usr/sbin/syslogd", name: "syslogd"),
                runtime: .unknown,
                isSystem: true
            ),
            Fixtures.developed(
                Fixtures.process(pid: 8, cpu: 1, command: "python worker.py", name: "python"),
                ports: [Fixtures.port(pid: 8, localPort: 8000, state: .listen)],
                workingDirectory: "/zebra",
                project: zebra,
                runtime: .python
            ),
            Fixtures.developed(
                Fixtures.process(pid: 9, cpu: 0.2, command: "/bin/zsh", name: "zsh"),
                runtime: .unknown
            ),
        ]
    }

    func testSearchHideSystemDevOnlyAndPort() {
        let rows = sample()
        let search = catalog.filtered(rows, query: ProcessQuery(searchText: "3000"))
        XCTAssertEqual(search.map(\.id), [2])

        let byProject = catalog.filtered(rows, query: ProcessQuery(searchText: "API"))
        XCTAssertEqual(byProject.map(\.id), [2])

        let byLauncher = catalog.filtered(rows, query: ProcessQuery(searchText: "cursor"))
        XCTAssertEqual(byLauncher.map(\.id), [2])

        let hidden = catalog.filtered(rows, query: ProcessQuery(hideSystem: true))
        XCTAssertEqual(hidden.map(\.id), [2, 8, 9])

        let dev = catalog.filtered(rows, query: ProcessQuery(developerRuntimesOnly: true))
        XCTAssertEqual(dev.map(\.id), [2, 8])

        let port = catalog.filtered(rows, query: ProcessQuery(port: 8000))
        XCTAssertEqual(port.map(\.id), [8])

        let named = catalog.filtered(rows, query: ProcessQuery(projectFilter: .named("Zebra")))
        XCTAssertEqual(named.map(\.id), [8])

        let none = catalog.filtered(rows, query: ProcessQuery(projectFilter: .unassigned))
        XCTAssertEqual(none.map(\.id), [5, 9])
    }

    func testSortBreaksTiesByPidAndKeepsMissingPortsLast() {
        let rows = sample()
        let byCPU = catalog.sorted(rows, key: .cpu, ascending: false)
        XCTAssertEqual(byCPU.map(\.id), [2, 5, 8, 9])

        let byPort = catalog.sorted(rows, key: .port, ascending: true)
        XCTAssertEqual(byPort.map(\.id), [2, 8, 5, 9])

        let byName = catalog.sorted(rows, key: .name, ascending: true)
        XCTAssertEqual(byName.map(\.process.name), ["node", "python", "syslogd", "zsh"])
    }

    func testGroupsByProjectWithUnassignedLast() {
        let groups = catalog.groupedByProject(sample())
        XCTAssertEqual(groups.map(\.name), ["api", "Zebra", "No project"])
        XCTAssertEqual(groups[0].processes.map(\.id), [2])
        XCTAssertEqual(groups[2].isUnassigned, true)
        XCTAssertEqual(groups[2].processes.map(\.id), [5, 9])
    }
}

final class KillServiceTests: XCTestCase {
    func testRefusesNonPositivePidsWithoutSignaling() {
        let spy = SpySignaler()
        let service = KillService(signaler: spy)
        XCTAssertEqual(service.kill(pid: 0, signal: .term), .failed(.invalidPid))
        XCTAssertEqual(service.kill(pid: -1, signal: .kill), .failed(.invalidPid))
        XCTAssertTrue(spy.calls.isEmpty)
    }

    func testMapsPermissionErrors() {
        let spy = SpySignaler()
        spy.error = .permissionDenied(pid: 40)
        let result = KillService(signaler: spy).kill(pid: 40, signal: .term)
        XCTAssertEqual(result, .failed(.permissionDenied(pid: 40)))
        XCTAssertTrue(result.failedMessage?.contains("Permission denied") == true)
    }

    func testKillOnPortDedupesPidsAndIgnoresTheRemoteSide() {
        let spy = SpySignaler()
        let service = KillService(signaler: spy)
        let bindings = [
            Fixtures.port(pid: 10, localPort: 3000),
            Fixtures.port(pid: 10, localAddress: "::", localPort: 3000),
            Fixtures.port(pid: 11, localPort: 49999, remoteAddress: "127.0.0.1", remotePort: 3000, state: .established),
            Fixtures.port(pid: 12, localPort: 3000),
        ]
        let results = service.killProcesses(boundToLocalPort: 3000, bindings: bindings, signal: .term)
        XCTAssertEqual(results, [
            .sent(pid: 10, signal: .term),
            .sent(pid: 12, signal: .term),
        ])
        XCTAssertEqual(spy.calls.map(\.1), [10, 12])
    }
}

extension KillResult {
    var failedMessage: String? {
        if case .failed(let error) = self { return error.userMessage }
        return nil
    }
}

final class SystemProcessSignalerTests: XCTestCase {
    func testSignalNumbersMatchThePlatform() {
        XCTAssertEqual(KillSignal.term.rawValue, SIGTERM)
        XCTAssertEqual(KillSignal.kill.rawValue, SIGKILL)
    }

    func testRejectsNonPositivePidsBeforeTheSyscall() {
        let signaler = SystemProcessSignaler()
        XCTAssertThrowsError(try signaler.send(.term, to: 0)) { error in
            XCTAssertEqual(error as? KillError, .invalidPid)
        }
        XCTAssertThrowsError(try signaler.send(.kill, to: -1))
    }

    func testMissingPidIsNoSuchProcess() throws {
        let signaler = SystemProcessSignaler()
        let pid: Int32 = 2_000_000_000
        XCTAssertThrowsError(try signaler.send(.term, to: pid)) { error in
            XCTAssertEqual(error as? KillError, .noSuchProcess(pid: pid))
        }
    }

    func testSIGTERMStopsAChildSleep() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        let pid = process.processIdentifier
        defer {
            if process.isRunning {
                kill(pid, SIGKILL)
                process.waitUntilExit()
            }
        }
        try SystemProcessSignaler().send(.term, to: pid)
        let finished = expectation(description: "sleep exits")
        DispatchQueue.global().async {
            process.waitUntilExit()
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
        XCTAssertFalse(process.isRunning)
    }
}

final class CommandRunnerTests: XCTestCase {
    func testEchoAndLargePipesDoNotDeadlock() throws {
        let runner = FoundationCommandRunner()
        let echo = try runner.run(executable: "/bin/echo", arguments: ["hello"])
        XCTAssertEqual(echo.status, 0)
        XCTAssertEqual(echo.stdout, "hello\n")

        let burst = try runner.run(
            executable: "/bin/bash",
            arguments: ["-c", "printf '%80000s' a; printf '%80000s' b >&2"]
        )
        XCTAssertEqual(burst.status, 0)
        XCTAssertEqual(burst.stdout.count, 80_000)
        XCTAssertEqual(burst.stderr.count, 80_000)
    }

    func testMissingExecutableThrows() {
        XCTAssertThrowsError(try FoundationCommandRunner().run(executable: "/no/such/devmonitor-bin", arguments: []))
    }
}

final class SnapshotTests: XCTestCase {
    func testAssemblerJoinsPortsProjectRuntimeAndParents() {
        let now = Fixtures.now
        let processes = [
            Fixtures.process(pid: 1, ppid: 0, user: "root", command: "/sbin/launchd"),
            Fixtures.process(pid: 10, ppid: 1, command: "/Applications/Cursor.app/Contents/MacOS/Cursor", name: "Cursor"),
            Fixtures.process(pid: 12, ppid: 10, elapsed: 30, command: "/bin/zsh", name: "zsh"),
            Fixtures.process(pid: 200, ppid: 12, cpu: 5.5, rssKB: 40960, elapsed: 10, command: "/usr/local/bin/node server.js", name: "node"),
        ]
        _ = now
        let ports = [
            Fixtures.port(pid: 200, localPort: 9229),
            Fixtures.port(pid: 200, localPort: 3000),
            Fixtures.port(pid: 200, localPort: 3000),
        ]
        let project = ProjectContext(
            workingDirectory: "/Users/luca/dev/api",
            gitRoot: "/Users/luca/dev",
            projectName: "api",
            manifestKind: .packageJSON,
            manifestPath: "/Users/luca/dev/api/package.json"
        )
        let rows = SnapshotAssembler().assemble(
            processes: processes,
            ports: ports,
            workingDirectories: [200: "/Users/luca/dev/api"],
            projects: ["/Users/luca/dev/api": project]
        )
        let node = rows.first { $0.id == 200 }
        XCTAssertEqual(node?.runtime, .node)
        XCTAssertEqual(node?.isSystem, false)
        XCTAssertEqual(node?.listeningPortNumbers, [3000, 9229])
        XCTAssertEqual(node?.ports.count, 2)
        XCTAssertEqual(node?.project?.projectName, "api")
        XCTAssertEqual(node?.parents.summary, "Cursor → zsh")
        XCTAssertEqual(rows.first { $0.id == 1 }?.isSystem, true)
    }

    func testLoaderBuildsADeveloperSnapshotAndToleratesEmptyLsof() {
        let ps = """
          1  0 root  0.0  100 1-00:00:00 /sbin/launchd
         50  1 luca  0.1  2000 02:00:00 /Applications/Cursor.app/Contents/MacOS/Cursor
         80  50 luca  0.0  500 01:00:00 /bin/zsh
        200  80 luca  5.5  40960 00:10:00 /usr/local/bin/node server.js
        """
        let listen = "node  200 luca  21u  IPv4 0xabc  0t0  TCP *:3000 (LISTEN)\n"
        let cwd = "p200\nfcwd\nn/Users/luca/dev/api\n"
        let runner = ScriptedRunner { executable, arguments in
            if executable == ProcessCommands.psExecutable {
                return CommandOutput(status: 0, stdout: ps, stderr: "")
            }
            if arguments == ProcessCommands.listenArguments {
                return CommandOutput(status: 0, stdout: listen, stderr: "")
            }
            if arguments == ProcessCommands.cwdArguments {
                return CommandOutput(status: 0, stdout: cwd, stderr: "")
            }
            return CommandOutput(status: 1, stdout: "", stderr: "")
        }
        var fs = InMemoryFileSystem()
        fs.entries.insert("/Users/luca/dev/.git")
        fs.files["/Users/luca/dev/api/package.json"] = #"{"name":"api"}"#
        let loader = LiveSnapshotLoader(
            runner: runner,
            detector: ProjectDetector(probe: fs),
            includeEstablished: false,
            includeUDP: false
        )
        let snapshot = loader.load(now: Fixtures.now)
        XCTAssertTrue(snapshot.warnings.isEmpty, snapshot.warnings.joined(separator: " | "))
        let node = snapshot.processes.first { $0.id == 200 }
        XCTAssertEqual(node?.runtime, .node)
        XCTAssertEqual(node?.listeningPortNumbers, [3000])
        XCTAssertEqual(node?.workingDirectory, "/Users/luca/dev/api")
        XCTAssertEqual(node?.project?.projectName, "api")
        XCTAssertEqual(node?.project?.gitRoot, "/Users/luca/dev")
        XCTAssertEqual(node?.parents.summary, "Cursor → zsh")
        XCTAssertFalse(runner.calls.contains { $0.arguments == ProcessCommands.establishedArguments })
        XCTAssertTrue(runner.calls.contains { $0.arguments == ProcessCommands.listenArguments })
    }

    func testLoaderReportsPsFailureAndTreatsLsofStatusOneAsEmpty() {
        let runner = ScriptedRunner { executable, _ in
            if executable == ProcessCommands.psExecutable {
                return CommandOutput(status: 1, stdout: "", stderr: "ps: denied")
            }
            return CommandOutput(status: 1, stdout: "", stderr: "")
        }
        let snapshot = LiveSnapshotLoader(
            runner: runner,
            detector: ProjectDetector(probe: InMemoryFileSystem())
        ).load()
        XCTAssertTrue(snapshot.processes.isEmpty)
        XCTAssertTrue(snapshot.warnings.contains { $0.contains("ps exited with status 1") })
    }

    func testDocumentedCommands() {
        XCTAssertEqual(ProcessCommands.psExecutable, "/bin/ps")
        XCTAssertEqual(ProcessCommands.psArguments, ["-axww", "-o", "pid=,ppid=,user=,%cpu=,rss=,etime=,command="])
        XCTAssertEqual(ProcessCommands.lsofExecutable, "/usr/sbin/lsof")
        XCTAssertEqual(ProcessCommands.listenArguments, ["-nP", "-iTCP", "-sTCP:LISTEN"])
        XCTAssertEqual(ProcessCommands.establishedArguments, ["-nP", "-iTCP", "-sTCP:ESTABLISHED"])
        XCTAssertEqual(ProcessCommands.udpArguments, ["-nP", "-iUDP"])
        XCTAssertEqual(ProcessCommands.cwdArguments, ["-nP", "-d", "cwd", "-Fn"])
    }
}

final class LocalFileSystemTests: XCTestCase {
    func testReadsARealFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("devmonitor-manifest-\(UUID().uuidString).json")
        try #"{"name":"temp"}"#.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let fs = LocalFileSystem()
        XCTAssertTrue(fs.entryExists(at: url.path))
        XCTAssertEqual(fs.read(at: url.path), #"{"name":"temp"}"#)
        XCTAssertFalse(fs.entryExists(at: url.path + ".missing"))
        XCTAssertNil(fs.read(at: url.path + ".missing"))
    }
}
