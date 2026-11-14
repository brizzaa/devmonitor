import XCTest
@testable import DevMonitorCore

final class MetricHistoryTests: XCTestCase {
    func testDropsOldestSamplesAndForgetsDeadPids() {
        var history = MetricHistory(capacity: 3)
        history.append(1)
        history.append(2)
        history.append(3)
        history.append(4)
        XCTAssertEqual(history.samples, [2, 3, 4])

        var store = ProcessMetricStore(capacity: 3)
        let first = Fixtures.developed(Fixtures.process(pid: 7, cpu: 1, command: "node a"), runtime: .node)
        let second = Fixtures.developed(Fixtures.process(pid: 7, cpu: 4, command: "node a"), runtime: .node)
        let other = Fixtures.developed(Fixtures.process(pid: 8, cpu: 2, command: "node b"), runtime: .node)
        store.record([first])
        store.record([second, other])
        store.record([other])
        XCTAssertEqual(store.series(for: 7), [])
        XCTAssertEqual(store.series(for: 8), [2, 2])
    }
}

final class ProjectTotalsTests: XCTestCase {
    func testSumsCPUMemoryAndUniquePortsPerProject() {
        let api = ProjectContext(workingDirectory: "/api", gitRoot: "/api", projectName: "api", manifestKind: .packageJSON, manifestPath: nil)
        let web = ProjectContext(workingDirectory: "/web", gitRoot: "/web", projectName: "web", manifestKind: nil, manifestPath: nil)
        let processes = [
            Fixtures.developed(
                Fixtures.process(pid: 1, cpu: 10, rssKB: 1024, command: "node a"),
                ports: [Fixtures.port(pid: 1, localPort: 3000), Fixtures.port(pid: 1, localPort: 3000)],
                project: api,
                runtime: .node
            ),
            Fixtures.developed(
                Fixtures.process(pid: 2, cpu: 5, rssKB: 512, command: "node b"),
                ports: [Fixtures.port(pid: 2, localPort: 9229)],
                project: api,
                runtime: .node
            ),
            Fixtures.developed(
                Fixtures.process(pid: 3, cpu: 20, rssKB: 2048, command: "python c"),
                ports: [Fixtures.port(pid: 3, localPort: 8000)],
                project: web,
                runtime: .python
            ),
            Fixtures.developed(Fixtures.process(pid: 4, cpu: 1, command: "zsh"), runtime: .unknown),
        ]
        let rows = ProjectTotals.summarize(processes)
        XCTAssertEqual(rows.map(\.name), ["web", "api", "No project"])
        XCTAssertEqual(rows[1].processCount, 2)
        XCTAssertEqual(rows[1].cpuPercent, 15)
        XCTAssertEqual(rows[1].memoryBytes, (1024 + 512) * 1024)
        XCTAssertEqual(rows[1].listeningPortCount, 2)
        XCTAssertTrue(rows[2].isUnassigned)

        let stats = DashboardStats.make(from: processes)
        XCTAssertEqual(stats.developerCount, 3)
        XCTAssertEqual(stats.developerCPU, 35)
        XCTAssertEqual(stats.listeningPortCount, 3)
    }
}

final class ProcessTreeBuilderTests: XCTestCase {
    func testBuildsAForestAndSortsChildrenByCPU() {
        let processes = [
            Fixtures.developed(Fixtures.process(pid: 1, ppid: 0, cpu: 0.1, command: "launchd")),
            Fixtures.developed(Fixtures.process(pid: 10, ppid: 1, cpu: 1, command: "zsh")),
            Fixtures.developed(Fixtures.process(pid: 11, ppid: 10, cpu: 9, command: "node a"), runtime: .node),
            Fixtures.developed(Fixtures.process(pid: 12, ppid: 10, cpu: 3, command: "node b"), runtime: .node),
        ]
        let roots = ProcessTreeBuilder().roots(from: processes)
        XCTAssertEqual(roots.map(\.id), [1])
        XCTAssertEqual(roots[0].children.map(\.id), [10])
        XCTAssertEqual(roots[0].children[0].children.map(\.id), [11, 12])
    }

    func testCutsCycles() {
        let processes = [
            Fixtures.developed(Fixtures.process(pid: 5, ppid: 6, command: "a")),
            Fixtures.developed(Fixtures.process(pid: 6, ppid: 5, command: "b")),
        ]
        let roots = ProcessTreeBuilder().roots(from: processes)
        func collect(_ nodes: [ProcessTreeNode]) -> Set<Int32> {
            var ids = Set<Int32>()
            for node in nodes {
                ids.insert(node.id)
                ids.formUnion(collect(node.children))
            }
            return ids
        }
        XCTAssertEqual(collect(roots), Set([5, 6]))
        XCTAssertEqual(roots.count, 1)
        XCTAssertTrue(roots[0].children.allSatisfy { $0.children.isEmpty })
    }
}

final class OrphanDetectorTests: XCTestCase {
    func testFlagsSessionRuntimesWhoseTerminalIsGone() {
        let launchd = ParentChain(
            ancestors: [Ancestor(pid: 1, name: "launchd", command: "/sbin/launchd", kind: .launchd)],
            links: [],
            launcher: .unknown,
            summary: ""
        )
        let cursor = ParentChain(
            ancestors: [],
            links: [ChainLink(pid: 50, label: "Cursor", command: "Cursor", kind: .cursor)],
            launcher: .cursor,
            summary: "Cursor"
        )
        let shell = ParentChain(
            ancestors: [],
            links: [ChainLink(pid: 80, label: "zsh", command: "zsh", kind: .zsh)],
            launcher: .zsh,
            summary: "zsh"
        )
        let orphan = Fixtures.developed(
            Fixtures.process(pid: 20, ppid: 1, command: "node server.js"),
            parents: launchd,
            runtime: .node
        )
        let inCursor = Fixtures.developed(
            Fixtures.process(pid: 21, ppid: 80, command: "node dev.js"),
            parents: cursor,
            runtime: .node
        )
        let inShell = Fixtures.developed(
            Fixtures.process(pid: 22, ppid: 80, command: "python app.py"),
            parents: shell,
            runtime: .python
        )
        let database = Fixtures.developed(
            Fixtures.process(pid: 23, ppid: 1, command: "postgres"),
            parents: launchd,
            runtime: .postgres
        )
        let found = OrphanDetector().orphans(in: [inCursor, orphan, inShell, database])
        XCTAssertEqual(found.map(\.id), [20])
    }
}

final class RestartAndURLTests: XCTestCase {
    func testQuotesTheWorkingDirectory() {
        let quoted = "cd '/Users/luca/O'" + "\\" + "'" + "'Hare' && node server.js --port 3000"
        XCTAssertEqual(
            RestartCommand.shellLine(command: "node server.js --port 3000", workingDirectory: "/Users/luca/O'Hare"),
            quoted
        )
        XCTAssertEqual(
            RestartCommand.shellLine(command: "  node server.js  ", workingDirectory: nil),
            "node server.js"
        )
    }

    func testLocalHTTPURLRewritesWildcards() {
        XCTAssertEqual(LocalHTTPURL.url(address: "*", port: 3000)?.absoluteString, "http://127.0.0.1:3000/")
        XCTAssertEqual(LocalHTTPURL.url(address: "0.0.0.0", port: 8080)?.absoluteString, "http://127.0.0.1:8080/")
        XCTAssertEqual(LocalHTTPURL.url(address: "::", port: 3000)?.absoluteString, "http://[::1]:3000/")
        XCTAssertEqual(LocalHTTPURL.url(address: "192.168.1.9", port: 5173)?.absoluteString, "http://192.168.1.9:5173/")
        XCTAssertNil(LocalHTTPURL.url(address: "*", port: 0))
        XCTAssertNil(LocalHTTPURL.url(address: "*", port: 70_000))
    }
}

private struct UnavailableRunner: CommandRunning {
    func run(executable: String, arguments: [String]) throws -> CommandOutput {
        throw CommandLaunchError(executable: executable, message: "no such file")
    }
}

final class DockerPsTests: XCTestCase {
    func testParsesJSONLinesAndSkipsGarbage() {
        let output = """
        {"ID":"abc123","Names":"api","Image":"node:20","Status":"Up 2 hours","Ports":"0.0.0.0:3000->3000/tcp","State":"running"}
        not json
        {"ID":"def456","Names":"db","Image":"postgres:16","Status":"Up 4 days","Ports":"127.0.0.1:5432->5432/tcp","State":"running"}
        """
        let rows = DockerPsParser().parse(output)
        XCTAssertEqual(rows.map(\.name), ["api", "db"])
        XCTAssertEqual(rows[0].ports, "0.0.0.0:3000->3000/tcp")
        XCTAssertEqual(rows[1].image, "postgres:16")
    }

    func testLoaderTreatsAMissingCLIAsUnavailable() {
        let result = DockerSnapshotLoader(runner: UnavailableRunner()).load()
        XCTAssertFalse(result.available)
        XCTAssertTrue(result.containers.isEmpty)
    }

    func testMissingDockerBinaryIsUnavailable() {
        let runner = ScriptedRunner { _, _ in
            CommandOutput(status: 127, stdout: "", stderr: "env: docker: No such file or directory\n")
        }
        let result = DockerSnapshotLoader(runner: runner).load()
        XCTAssertFalse(result.available)
    }

    func testLoaderSurfacesDaemonErrorsButKeepsTheCLIAvailable() {
        let runner = ScriptedRunner { _, _ in
            CommandOutput(status: 1, stdout: "", stderr: "Cannot connect to the Docker daemon\n")
        }
        let result = DockerSnapshotLoader(runner: runner).load()
        XCTAssertTrue(result.available)
        XCTAssertEqual(result.warning, "Cannot connect to the Docker daemon")
        XCTAssertTrue(result.containers.isEmpty)
    }
}
