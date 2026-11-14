#if os(macOS)
import SwiftUI
import DevMonitorCore

struct PortRow: Identifiable {
    var binding: PortBinding
    var process: DeveloperProcess
    var id: String { binding.id }
}

struct PortsView: View {
    var rows: [PortRow]
    var exactPort: Int?
    @Environment(AppModel.self) private var model
    @State private var selectedRow: PortRow.ID?

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                TextField("3000", text: $model.portQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospacedDigit())
                    .frame(width: 120)
                    .accessibilityLabel("Port number")
                VStack(alignment: .leading, spacing: 2) {
                    Text("What is using this port?")
                        .font(.headline)
                    Text(hint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button(killTitle) {
                    if let exactPort {
                        model.askKill(port: exactPort, signal: .term)
                    }
                }
                .disabled(exactPort == nil || !rows.contains { $0.binding.localPort == exactPort })
            }
            .padding(16)

            if rows.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "network.slash",
                    description: Text(emptyDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(rows, selection: $selectedRow) {
                    TableColumn("Port") { row in
                        Text("\(row.binding.localPort)")
                            .font(.body.monospacedDigit().weight(.semibold))
                    }
                    .width(min: 56, ideal: 70, max: 90)
                    TableColumn("Proto") { row in
                        Text(row.binding.transport.rawValue.uppercased())
                            .font(.body.monospaced())
                    }
                    .width(min: 52, ideal: 64, max: 80)
                    TableColumn("State") { row in
                        Text(row.binding.state.rawValue)
                            .foregroundStyle(row.binding.state == .listen ? .primary : .secondary)
                    }
                    .width(min: 88, ideal: 110)
                    TableColumn("PID") { row in
                        Text("\(row.process.id)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 56, ideal: 72)
                    TableColumn("Process") { row in
                        HStack(spacing: 6) {
                            RuntimeBadge(runtime: row.process.runtime)
                            Text(row.process.process.name)
                                .fontWeight(row.process.runtime.isDeveloperFacing ? .semibold : .regular)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 140, ideal: 180)
                    TableColumn("Address") { row in
                        Text(ProcessFormatting.endpoint(row.binding))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }
                    .width(min: 180, ideal: 260)
                    TableColumn("Project") { row in
                        Text(row.process.project?.projectName ?? "—")
                            .lineLimit(1)
                    }
                    .width(min: 90, ideal: 120)
                    TableColumn("Command") { row in
                        Text(row.process.process.command)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 180, ideal: 280)
                }
                .contextMenu(forSelectionType: PortRow.ID.self) { ids in
                    if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                        Button("Terminate (SIGTERM)…") { model.askKill(pid: row.process.id, signal: .term) }
                        Button("Force Quit (SIGKILL)…") { model.askKill(pid: row.process.id, signal: .kill) }
                        Button("Kill whatever is on port \(row.binding.localPort)…") {
                            model.askKill(port: row.binding.localPort, signal: .term)
                        }
                        Divider()
                        Button("Copy PID") { Clipboard.copy(String(row.process.id)) }
                        Button("Copy Command") { Clipboard.copy(row.process.process.command) }
                        if let cwd = row.process.workingDirectory {
                            Button("Copy Working Directory") { Clipboard.copy(cwd) }
                            Button("Show in Finder") { Finder.reveal(cwd) }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedRow) { _, id in
            guard let id, let row = rows.first(where: { $0.id == id }) else { return }
            model.selectedPID = row.process.id
        }
    }

    private var exactMatches: Int {
        guard let exactPort else { return 0 }
        return Set(rows.filter { $0.binding.localPort == exactPort }.map(\.process.id)).count
    }

    private var hint: String {
        if model.portQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Leave this empty to list every socket, or type 3000 to jump to that port."
        }
        if let exactPort, exactMatches > 0 {
            return "\(exactMatches) process\(exactMatches == 1 ? "" : "es") bound to local port \(exactPort)."
        }
        if exactPort == nil {
            return "Showing ports that start with \(model.portQuery)."
        }
        return "Nothing is bound to local port \(exactPort ?? 0)."
    }

    private var killTitle: String {
        if let exactPort {
            return "Kill whatever is on port \(exactPort)"
        }
        return "Kill whatever is on this port"
    }

    private var emptyTitle: String {
        if let exactPort {
            return "Nothing is using port \(exactPort)"
        }
        if model.portQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No sockets"
        }
        return "No matching ports"
    }

    private var emptyDescription: String {
        if model.portQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "lsof did not report listening sockets for the processes you can see. Other users’ ports stay hidden unless DevMonitor is run as an administrator."
        }
        return "Try the full port number. Clients connected to a remote server are not listed: only sockets whose local port matches."
    }
}
#endif
