#if os(macOS)
import SwiftUI
import DevMonitorCore

struct ProcessTableView: View {
    var rows: [DeveloperProcess]
    var cpuSeries: (Int32) -> [Double]
    @Binding var sortOrder: [KeyPathComparator<DeveloperProcess>]
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Table(rows, selection: $model.selectedPID, sortOrder: $sortOrder) {
            TableColumn("PID", value: \.pidSort) { process in
                Text("\(process.process.pid)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 56, ideal: 72, max: 90)

            TableColumn("Name", value: \.nameSort) { process in
                HStack(spacing: 8) {
                    Button {
                        model.toggleWatch(pid: process.id)
                    } label: {
                        Image(systemName: model.watchedPIDs.contains(process.id) ? "star.fill" : "star")
                            .foregroundStyle(model.watchedPIDs.contains(process.id) ? Theme.amber : Theme.quiet)
                    }
                    .buttonStyle(.borderless)
                    .help("Watch this process and notify when it exits")
                    RuntimeBadge(runtime: process.runtime)
                    Text(process.process.name)
                        .fontWeight(process.runtime.isDeveloperFacing ? .semibold : .regular)
                        .foregroundStyle(process.isSystem ? .tertiary : .primary)
                        .lineLimit(1)
                }
            }
            .width(min: 160, ideal: 220)

            TableColumn("CPU %", value: \.cpuSort) { process in
                HStack(spacing: 6) {
                    Text(String(format: "%.1f", process.process.cpuPercent))
                        .font(.body.monospacedDigit())
                    Sparkline(values: cpuSeries(process.id), color: process.runtime.isDeveloperFacing ? process.runtime.tint : Theme.cyan)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 150, max: 180)

            TableColumn("Memory", value: \.memorySort) { process in
                Text(ByteFormat.string(bytes: process.process.memoryBytes))
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 72, ideal: 88, max: 110)

            TableColumn("User", value: \.userSort) { process in
                Text(process.process.user)
                    .lineLimit(1)
            }
            .width(min: 72, ideal: 100, max: 140)

            TableColumn("Uptime", value: \.uptimeSort) { process in
                Text(UptimeFormat.string(seconds: process.process.elapsedSeconds))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 72, ideal: 84, max: 110)

            TableColumn("Started", value: \.startSort) { process in
                Text(StartedFormat.string(process.process.startTime, now: Date()))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 88, ideal: 148, max: 170)

            TableColumn("Ports", value: \.portSort) { process in
                Text(ProcessFormatting.portSummary(process))
                    .font(.body.monospacedDigit())
                    .help(portHelp(process))
            }
            .width(min: 72, ideal: 110, max: 160)

            TableColumn("Project", value: \.projectSort) { process in
                Text(process.project?.projectName ?? "—")
                    .lineLimit(1)
                    .foregroundStyle(process.project?.projectName == nil ? .tertiary : .primary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Command", value: \.commandSort) { process in
                Text(process.process.command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(process.process.command)
            }
            .width(min: 220, ideal: 360)
        }
        .contextMenu(forSelectionType: DeveloperProcess.ID.self) { ids in
            if let pid = ids.first, let process = model.process(pid: pid) {
                Button("Terminate (SIGTERM)…") { model.askKill(pid: process.id, signal: .term) }
                Button("Force Quit (SIGKILL)…") { model.askKill(pid: process.id, signal: .kill) }
                if !process.listeningPortNumbers.isEmpty {
                    Menu("Kill whatever is on port") {
                        ForEach(process.listeningPortNumbers, id: \.self) { port in
                            Button("\(port)") { model.askKill(port: port, signal: .term) }
                        }
                    }
                }
                Divider()
                Button("Copy PID") { Clipboard.copy(String(process.id)) }
                Button("Copy Command") { Clipboard.copy(process.process.command) }
                if let cwd = process.workingDirectory {
                    Button("Copy Working Directory") { Clipboard.copy(cwd) }
                    Button("Show in Finder") { Finder.reveal(cwd) }
                }
            }
        }
    }

    private func portHelp(_ process: DeveloperProcess) -> String {
        if process.ports.isEmpty { return "No sockets" }
        return process.ports.map { binding in
            "\(binding.transport.rawValue.uppercased()) \(ProcessFormatting.endpoint(binding)) \(binding.state.rawValue)"
        }.joined(separator: "\n")
    }
}
#endif
