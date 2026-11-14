import Foundation

/// Parses `ps -axww -o pid=,ppid=,user=,%cpu=,rss=,etime=,command=`.
/// The first six columns are whitespace-separated. Everything after that is the
/// command line, with its internal spacing preserved. `rss` is kilobytes, as on macOS.
public struct PSParser {
    public init() {}

    public func parse(_ output: String, now: Date) -> [ProcessRecord] {
        var records: [ProcessRecord] = []
        var seen = Set<Int32>()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let record = parseLine(String(line), now: now) else { continue }
            if seen.insert(record.pid).inserted {
                records.append(record)
            }
        }
        return records
    }

    private func parseLine(_ line: String, now: Date) -> ProcessRecord? {
        var rest = line[...]
        var fields: [String] = []
        fields.reserveCapacity(6)
        for _ in 0..<6 {
            rest = rest.drop(while: { $0 == " " || $0 == "\t" })
            if rest.isEmpty { return nil }
            if let split = rest.firstIndex(where: { $0 == " " || $0 == "\t" }) {
                fields.append(String(rest[..<split]))
                rest = rest[split...]
            } else {
                fields.append(String(rest))
                rest = Substring()
            }
        }
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        let command = String(rest)
        guard fields.count == 6, !command.isEmpty else { return nil }
        guard let pid = Int32(fields[0]), let ppid = Int32(fields[1]) else { return nil }
        let cpuText = fields[3].replacingOccurrences(of: ",", with: ".")
        guard let cpu = Double(cpuText), let rssKB = UInt64(fields[4]) else { return nil }
        guard let elapsed = EtimeParser.seconds(from: fields[5]) else { return nil }
        let memoryBytes = rssKB > UInt64.max / 1024 ? UInt64.max : rssKB * 1024

        return ProcessRecord(
            pid: pid,
            ppid: ppid,
            user: fields[2],
            cpuPercent: cpu,
            memoryBytes: memoryBytes,
            elapsedSeconds: elapsed,
            startTime: now.addingTimeInterval(-elapsed),
            command: command,
            name: ProcessName.derive(from: command)
        )
    }
}
