import XCTest
@testable import DevMonitorCore

final class LsofParserTests: XCTestCase {
    func testParsesListeningIPv4IPv6AndEstablishedSockets() {
        let sample = """
        COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        lsof: WARNING: unable to stat some files
        node      12345 luca   21u  IPv4 0xabc      0t0  TCP *:3000 (LISTEN)
        node      12345 luca   22u  IPv6 0xdef      0t0  TCP [::1]:3000 (LISTEN)
        node      12345 luca   23u  IPv6 0xaaa      0t0  TCP [fe80::1%en0]:5353 (LISTEN)
        postgres    999 postgres 5u  IPv4 0x111     0t0  TCP 127.0.0.1:5432 (LISTEN)
        python       55 luca    8u  IPv4 0x222     0t0  TCP 10.0.0.5:51234->93.184.216.34:443 (ESTABLISHED)
        redis-ser     8 luca    6u  IPv4 0x333     0t0  UDP *:6379
        """
        let rows = LsofParser().parse(sample)
        XCTAssertEqual(rows.count, 6)

        XCTAssertEqual(rows[0].pid, 12345)
        XCTAssertEqual(rows[0].command, "node")
        XCTAssertEqual(rows[0].transport, .tcp)
        XCTAssertEqual(rows[0].localAddress, "*")
        XCTAssertEqual(rows[0].localPort, 3000)
        XCTAssertEqual(rows[0].state, .listen)
        XCTAssertNil(rows[0].remotePort)

        XCTAssertEqual(rows[1].localAddress, "::1")
        XCTAssertEqual(rows[1].localPort, 3000)
        XCTAssertEqual(rows[1].state, .listen)

        XCTAssertEqual(rows[2].localAddress, "fe80::1%en0")
        XCTAssertEqual(rows[2].localPort, 5353)

        XCTAssertEqual(rows[3].user, "postgres")
        XCTAssertEqual(rows[3].localAddress, "127.0.0.1")
        XCTAssertEqual(rows[3].localPort, 5432)

        XCTAssertEqual(rows[4].state, .established)
        XCTAssertEqual(rows[4].localAddress, "10.0.0.5")
        XCTAssertEqual(rows[4].localPort, 51234)
        XCTAssertEqual(rows[4].remoteAddress, "93.184.216.34")
        XCTAssertEqual(rows[4].remotePort, 443)

        XCTAssertEqual(rows[5].transport, .udp)
        XCTAssertEqual(rows[5].localPort, 6379)
        XCTAssertEqual(rows[5].state, .listen)
        XCTAssertEqual(rows[5].command, "redis-ser")
    }

    func testPortLookupAnswersWhatIsUsingPort3000() {
        let rows = LsofParser().parse("""
        node  10 luca 21u IPv4 0x1 0t0 TCP *:3000 (LISTEN)
        node  10 luca 22u IPv6 0x2 0t0 TCP *:3000 (LISTEN)
        node  11 luca  8u IPv4 0x3 0t0 TCP 127.0.0.1:49999->127.0.0.1:3000 (ESTABLISHED)
        python 12 luca 4u IPv4 0x4 0t0 TCP *:8080 (LISTEN)
        """)
        let lookup = PortLookup()
        let listeners = lookup.bindings(on: 3000, in: rows, listeningOnly: true)
        XCTAssertEqual(listeners.map(\.pid), [10, 10])
        let anyone = lookup.bindings(on: 3000, in: rows, listeningOnly: false)
        XCTAssertEqual(anyone.map(\.pid), [10, 10])
        XCTAssertTrue(lookup.bindings(on: 1, in: rows).isEmpty)
        // The client side of a connection to :3000 is not "using port 3000".
        XCTAssertFalse(anyone.contains { $0.pid == 11 })
    }

    func testIgnoresMalformedLines() {
        XCTAssertTrue(LsofParser().parse("not a socket line\n").isEmpty)
    }
}
