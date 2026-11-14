import XCTest
@testable import DevMonitorCore

final class CwdParserTests: XCTestCase {
    func testReadsCwdAndIgnoresOtherFileDescriptors() {
        let output = """
        p10
        ftxt
        n/usr/local/bin/node
        fcwd
        n/Users/luca/dev/api
        p11
        fcwd
        n/tmp/work
        p12
        fcwd
        n
        """
        let map = CwdParser().parse(output)
        XCTAssertEqual(map[10], "/Users/luca/dev/api")
        XCTAssertEqual(map[11], "/tmp/work")
        XCTAssertNil(map[12])
    }
}

final class FormattingTests: XCTestCase {
    func testEtimeParser() {
        XCTAssertEqual(EtimeParser.seconds(from: "03:04"), 184)
        XCTAssertEqual(EtimeParser.seconds(from: "01:02:03"), 3723)
        XCTAssertEqual(EtimeParser.seconds(from: "2-01:02:03"), 2 * 86_400 + 3723)
        XCTAssertEqual(EtimeParser.seconds(from: "00:00"), 0)
        XCTAssertEqual(EtimeParser.seconds(from: "1-00:00:00"), 86_400)
        XCTAssertNil(EtimeParser.seconds(from: "nope"))
        XCTAssertNil(EtimeParser.seconds(from: "01:99"))
        XCTAssertNil(EtimeParser.seconds(from: ""))
    }

    func testUptimeFormat() {
        XCTAssertEqual(UptimeFormat.string(seconds: 0), "0s")
        XCTAssertEqual(UptimeFormat.string(seconds: 45), "45s")
        XCTAssertEqual(UptimeFormat.string(seconds: 59), "59s")
        XCTAssertEqual(UptimeFormat.string(seconds: 60), "1m 00s")
        XCTAssertEqual(UptimeFormat.string(seconds: 184), "3m 04s")
        XCTAssertEqual(UptimeFormat.string(seconds: 3599), "59m 59s")
        XCTAssertEqual(UptimeFormat.string(seconds: 3600), "1h 0m")
        XCTAssertEqual(UptimeFormat.string(seconds: 3723), "1h 2m")
        XCTAssertEqual(UptimeFormat.string(seconds: 90_000), "1d 1h")
    }

    func testByteFormat() {
        XCTAssertEqual(ByteFormat.string(bytes: 0), "0 B")
        XCTAssertEqual(ByteFormat.string(bytes: 512), "512 B")
        XCTAssertEqual(ByteFormat.string(bytes: 1024), "1 KB")
        XCTAssertEqual(ByteFormat.string(bytes: 1536), "1.5 KB")
        XCTAssertEqual(ByteFormat.string(bytes: 1_048_576), "1 MB")
        XCTAssertEqual(ByteFormat.string(bytes: 81920 * 1024), "80 MB")
    }

    func testStartedFormatUsesTheProvidedCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(StartedFormat.string(epoch, now: epoch, calendar: calendar), "00:00:00")
        let later = Date(timeIntervalSince1970: 86_400 * 2 + 3661)
        XCTAssertEqual(StartedFormat.string(later, now: epoch, calendar: calendar), "1970-01-03 01:01")
    }
}

final class PathNormalizerTests: XCTestCase {
    func testNormalizesAndWalksParents() {
        XCTAssertEqual(PathNormalizer.normalize("/Users//luca/../dev/"), "/Users/dev")
        XCTAssertEqual(PathNormalizer.normalize("/"), "/")
        XCTAssertEqual(PathNormalizer.ancestors(of: "/repo/services/api"), ["/repo/services/api", "/repo/services", "/repo", "/"])
        XCTAssertEqual(PathNormalizer.basename("/repo/services"), "services")
        XCTAssertNil(PathNormalizer.parent(of: "/"))
    }
}
