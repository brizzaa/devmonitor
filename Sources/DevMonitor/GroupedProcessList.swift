#if os(macOS)
import SwiftUI
import DevMonitorCore

struct GroupedProcessList: View {
    var groups: [ProjectGroup]
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedPID) {
            ForEach(groups) { group in
                Section(group.name) {
                    ForEach(group.processes) { process in
                        GroupedProcessRow(process: process)
                            .tag(process.id)
                            .contextMenu {
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
            }
        }
        .listStyle(.inset)
    }
}

private struct GroupedProcessRow: View {
    var process: DeveloperProcess

    var body: some View {
        HStack(spacing: 10) {
            RuntimeBadge(runtime: process.runtime)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(process.process.name)
                        .fontWeight(process.runtime.isDeveloperFacing ? .semibold : .regular)
                    Text("\(process.process.pid)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", process.process.cpuPercent))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.string(bytes: process.process.memoryBytes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if process.listeningPortNumbers.isEmpty == false {
                        Text(ProcessFormatting.portSummary(process))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(process.process.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .opacity(process.isSystem ? 0.55 : 1)
    }
}
#endif
