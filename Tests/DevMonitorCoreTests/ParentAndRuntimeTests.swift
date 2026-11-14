import XCTest
@testable import DevMonitorCore

final class LauncherClassifierTests: XCTestCase {
    private let classifier = LauncherClassifier()

    func testDistinguishesCursorFromVSCodeAndCommonTerminals() {
        XCTAssertEqual(classifier.classify(name: "Cursor Helper (Plugin)", command: "/Applications/Cursor.app/Contents/MacOS/Cursor"), .cursor)
        XCTAssertEqual(classifier.classify(name: "Cursor", command: "/Applications/Cursor.app/Contents/MacOS/Cursor"), .cursor)
        XCTAssertEqual(classifier.classify(name: "Code Helper", command: "/Applications/Visual Studio Code.app/Contents/MacOS/Electron"), .vscode)
        XCTAssertEqual(classifier.classify(name: "Code", command: "/Applications/Visual Studio Code.app/Contents/MacOS/Code"), .vscode)
        XCTAssertEqual(classifier.classify(name: "iTerm2", command: "/Applications/iTerm.app/Contents/MacOS/iTerm2"), .iterm)
        XCTAssertEqual(classifier.classify(name: "Terminal", command: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"), .terminal)
        XCTAssertEqual(classifier.classify(name: "tmux", command: "tmux: server"), .tmux)
        XCTAssertEqual(classifier.classify(name: "-zsh", command: "-zsh"), .zsh)
        XCTAssertEqual(classifier.classify(name: "node", command: "node server.js"), .unknown)
        XCTAssertEqual(classifier.classify(name: "launchd", command: "/sbin/launchd"), .launchd)
        XCTAssertEqual(classifier.classify(name: "WebStorm", command: "webstorm"), .jetbrains)
    }
}

final class ParentChainResolverTests: XCTestCase {
    func testSummarizesITermAroundTmuxAndZsh() {
        let processes = [
            Fixtures.process(pid: 1, ppid: 0, user: "root", command: "/sbin/launchd"),
            Fixtures.process(pid: 50, ppid: 1, command: "/Applications/iTerm.app/Contents/MacOS/iTerm2", name: "iTerm2"),
            Fixtures.process(pid: 80, ppid: 50, command: "tmux: server", name: "tmux"),
            Fixtures.process(pid: 90, ppid: 80, command: "-zsh", name: "zsh"),
            Fixtures.process(pid: 420, ppid: 90, command: "/usr/local/bin/node server.js", name: "node"),
        ]
        let chain = ParentChainResolver().resolve(pid: 420, processes: processes)
        XCTAssertEqual(chain.summary, "iTerm2 → tmux → zsh")
        XCTAssertEqual(chain.launcher, .iterm)
        XCTAssertEqual(chain.ancestors.map(\.pid), [90, 80, 50, 1])
        XCTAssertEqual(chain.links.map(\.label), ["iTerm2", "tmux", "zsh"])
    }

    func testCollapsesCursorHelpers() {
        let processes = [
            Fixtures.process(pid: 1, ppid: 0, user: "root", command: "/sbin/launchd"),
            Fixtures.process(pid: 10, ppid: 1, command: "/Applications/Cursor.app/Contents/MacOS/Cursor", name: "Cursor"),
            Fixtures.process(pid: 11, ppid: 10, command: "/Applications/Cursor.app/Contents/MacOS/Cursor", name: "Cursor Helper"),
            Fixtures.process(pid: 12, ppid: 11, command: "/bin/zsh", name: "zsh"),
            Fixtures.process(pid: 13, ppid: 12, command: "node server.js", name: "node"),
        ]
        let chain = ParentChainResolver().resolve(pid: 13, processes: processes)
        XCTAssertEqual(chain.summary, "Cursor → zsh")
        XCTAssertEqual(chain.launcher, .cursor)
    }

    func testKeepsAnImmediateToolParentSuchAsNpm() {
        let processes = [
            Fixtures.process(pid: 10, ppid: 1, command: "/Applications/Cursor.app/Contents/MacOS/Cursor", name: "Cursor"),
            Fixtures.process(pid: 12, ppid: 10, command: "/bin/zsh", name: "zsh"),
            Fixtures.process(pid: 14, ppid: 12, command: "npm run dev", name: "npm"),
            Fixtures.process(pid: 15, ppid: 14, command: "node server.js", name: "node"),
        ]
        let chain = ParentChainResolver().resolve(pid: 15, processes: processes)
        XCTAssertEqual(chain.summary, "Cursor → zsh → npm")
        XCTAssertEqual(chain.launcher, .cursor)
    }

    func testShellOnlyAndLaunchdDaemon() {
        let processes = [
            Fixtures.process(pid: 1, ppid: 0, user: "root", command: "/sbin/launchd"),
            Fixtures.process(pid: 20, ppid: 1, command: "/bin/zsh", name: "zsh"),
            Fixtures.process(pid: 21, ppid: 20, command: "npm start", name: "npm"),
            Fixtures.process(pid: 30, ppid: 1, user: "postgres", command: "postgres: checkpointer", name: "postgres"),
        ]
        let shell = ParentChainResolver().resolve(pid: 21, processes: processes)
        XCTAssertEqual(shell.summary, "zsh")
        XCTAssertEqual(shell.launcher, .zsh)

        let daemon = ParentChainResolver().resolve(pid: 30, processes: processes)
        XCTAssertEqual(daemon.summary, "")
        XCTAssertEqual(daemon.launcher, .unknown)
        XCTAssertEqual(daemon.ancestors.map(\.kind), [.launchd])
    }

    func testBreaksParentCycles() {
        let processes = [
            Fixtures.process(pid: 5, ppid: 6, command: "a", name: "a"),
            Fixtures.process(pid: 6, ppid: 5, command: "b", name: "b"),
        ]
        let chain = ParentChainResolver().resolve(pid: 5, processes: processes)
        XCTAssertEqual(chain.ancestors.map(\.pid), [6])
    }
}

final class RuntimeClassifierTests: XCTestCase {
    private let classifier = RuntimeClassifier()

    func testClassifiesCommonDeveloperRuntimes() {
        let cases: [(String, String, DevRuntime)] = [
            ("node", "/usr/local/bin/node server.js", .node),
            ("next-server", "next-server", .node),
            ("npm", "npm run dev", .node),
            ("tsx", "tsx watch src/index.ts", .node),
            ("bun", "bun run dev", .bun),
            ("deno", "deno run main.ts", .deno),
            ("python3.12", "/opt/homebrew/bin/python3.12 app.py", .python),
            ("gunicorn", "gunicorn app:app", .python),
            ("uvicorn", "uvicorn app:app --port 8000", .python),
            ("puma", "puma -C config/puma.rb", .ruby),
            ("ruby", "ruby bin/rails server", .ruby),
            ("java", "/usr/bin/java -jar service.jar", .java),
            ("go", "go run ./cmd/api", .go),
            ("dlv", "dlv debug", .go),
            ("server", "/var/folders/ab/go-build/xx/b001/exe/server", .go),
            ("__debug_bin123", "__debug_bin123", .go),
            ("api", "/Users/luca/dev/api/target/debug/api", .rust),
            ("cargo", "cargo run", .rust),
            ("worker", "/Users/luca/dev/app/.build/debug/worker", .swift),
            ("com.docker.backend", "/Applications/Docker.app/Contents/MacOS/com.docker.backend", .docker),
            ("postgres", "postgres: checkpointer", .postgres),
            ("redis-server", "redis-server *:6379", .redis),
            ("mysqld", "mysqld", .mysql),
            ("mongod", "mongod", .mongo),
            ("nginx", "nginx: worker process", .nginx),
            ("php-fpm", "php-fpm: pool www", .php),
            ("php8.3", "php8.3 -S localhost:8080", .php),
            ("beam.smp", "/usr/local/lib/erlang/erts/bin/beam.smp", .beam),
            ("dotnet", "dotnet api.dll", .dotnet),
            ("kubectl", "kubectl port-forward", .kubernetes),
            ("WindowServer", "/System/Library/PrivateFrameworks/SkyLight.framework/WindowServer", .unknown),
            ("phpstorm", "phpstorm", .unknown),
        ]
        for item in cases {
            XCTAssertEqual(
                classifier.classify(name: item.0, command: item.1),
                item.2,
                "\(item.0) \(item.1)"
            )
        }
    }
}

final class SystemProcessHeuristicTests: XCTestCase {
    private let heuristic = SystemProcessHeuristic()

    func testDevRuntimesAreNeverSystem() {
        let node = Fixtures.process(pid: 4, user: "root", command: "/usr/local/bin/node server.js")
        XCTAssertFalse(heuristic.isSystem(node, runtime: .node))
    }

    func testKnownSystemProcessesAndPrefixes() {
        let kernel = Fixtures.process(pid: 0, user: "root", command: "kernel_task", name: "kernel_task")
        XCTAssertTrue(heuristic.isSystem(kernel, runtime: .unknown))

        let syslog = Fixtures.process(pid: 20, user: "root", command: "/usr/sbin/syslogd")
        XCTAssertTrue(heuristic.isSystem(syslog, runtime: .unknown))

        let webkit = Fixtures.process(pid: 21, user: "luca", command: "/System/Library/Frameworks/WebKit.framework/com.apple.WebKit.Networking", name: "com.apple.WebKit.Networking")
        XCTAssertTrue(heuristic.isSystem(webkit, runtime: .unknown))

        let trustd = Fixtures.process(pid: 22, user: "root", command: "/usr/libexec/trustd")
        XCTAssertTrue(heuristic.isSystem(trustd, runtime: .unknown))
    }

    func testUserBinariesAndShellsStayVisible() {
        let worker = Fixtures.process(pid: 30, command: "/Users/luca/bin/worker")
        XCTAssertFalse(heuristic.isSystem(worker, runtime: .unknown))

        let shell = Fixtures.process(pid: 31, command: "/bin/zsh", name: "zsh")
        XCTAssertFalse(heuristic.isSystem(shell, runtime: .unknown))
    }
}
