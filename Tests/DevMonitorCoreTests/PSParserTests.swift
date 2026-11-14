import XCTest
@testable import DevMonitorCore

final class PSParserTests: XCTestCase {
    private let now = Fixtures.now

    func testParsesPidNameCpuMemoryUserUptimeCommandAndStartTime() {
        let sample = """
          420  110 luca  12.5  81920 01:02:03 /usr/local/bin/node server.js --port 3000
        """
        let rows = PSParser().parse(sample, now: now)
        XCTAssertEqual(rows.count, 1)
        let row = rows[0]
        XCTAssertEqual(row.pid, 420)
        XCTAssertEqual(row.ppid, 110)
        XCTAssertEqual(row.user, "luca")
        XCTAssertEqual(row.cpuPercent, 12.5)
        XCTAssertEqual(row.memoryBytes, 81920 * 1024)
        XCTAssertEqual(row.elapsedSeconds, 3723)
        XCTAssertEqual(row.command, "/usr/local/bin/node server.js --port 3000")
        XCTAssertEqual(row.name, "node")
        XCTAssertEqual(row.startTime, now.addingTimeInterval(-3723))
    }

    func testPreservesInternalSpacesInTheCommand() {
        let sample = "  7  1 luca  0.0  10 00:01 /usr/local/bin/node  server.js --port 3000\n"
        let rows = PSParser().parse(sample, now: now)
        XCTAssertEqual(rows.first?.command, "/usr/local/bin/node  server.js --port 3000")
    }

    func testParsesDayElapsedTimeCommaDecimalAndLoginShellName() {
        let sample = """
        1 0 root 0,4 2048 2-01:02:03 /sbin/launchd
        88 1 luca 1 512 03:04 -zsh
        90 88 luca 0.0 64 00:09 postgres: checkpointer
        this is not a process
        """
        let rows = PSParser().parse(sample, now: now)
        XCTAssertEqual(rows.map(\.pid), [1, 88, 90])
        XCTAssertEqual(rows[0].cpuPercent, 0.4)
        XCTAssertEqual(rows[0].elapsedSeconds, 2 * 86_400 + 3_723)
        XCTAssertEqual(rows[0].name, "launchd")
        XCTAssertEqual(rows[1].name, "zsh")
        XCTAssertEqual(rows[1].elapsedSeconds, 184)
        XCTAssertEqual(rows[2].name, "postgres")
        XCTAssertEqual(rows[2].command, "postgres: checkpointer")
    }

    func testSkipsDuplicatePidsAndBlankLines() {
        let sample = """

        5 1 luca 1.0 10 00:01 first
        5 1 luca 9.0 10 00:02 second
        """
        let rows = PSParser().parse(sample, now: now)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].command, "first")
    }

    func testEmptyOutputIsAnEmptyList() {
        XCTAssertTrue(PSParser().parse("", now: now).isEmpty)
        XCTAssertTrue(PSParser().parse("   \n\n", now: now).isEmpty)
    }
}
