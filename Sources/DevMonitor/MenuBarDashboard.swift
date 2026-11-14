#if os(macOS)
import SwiftUI
import DevMonitorCore

struct MenuBarDashboard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DevMonitor")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f%%", model.dashboard.developerCPU))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.cyan)
            }
            Sparkline(values: model.hostCPU.samples, color: Theme.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Top dev processes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.quiet)
            if top.isEmpty {
                Text(model.isLoading ? "Reading processes…" : "No developer runtimes right now.")
                    .font(.callout)
                    .foregroundStyle(Theme.quiet)
            } else {
                ForEach(top) { process in
                    HStack(spacing: 8) {
                        RuntimeBadge(runtime: process.runtime)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(process.process.name)
                                .lineLimit(1)
                            Text("\(process.id) · \(ProcessFormatting.portSummary(process))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.quiet)
                        }
                        Spacer(minLength: 4)
                        Text(String(format: "%.0f%%", process.process.cpuPercent))
                            .font(.callout.monospacedDigit())
                        Button {
                            model.quickTerminate(pid: process.id)
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Send SIGTERM")
                    }
                }
            }

            if !ports.isEmpty {
                Text("Listening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.quiet)
                ForEach(Array(ports.prefix(6))) { row in
                    HStack {
                        Text("\(row.binding.localPort)")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .frame(width: 54, alignment: .leading)
                        Text(row.process.process.name)
                            .lineLimit(1)
                        Spacer()
                        if let url = LocalHTTPURL.url(address: row.binding.localAddress, port: row.binding.localPort),
                           row.binding.transport == .tcp {
                            Button("Open") { WorkspaceOpener.openInBrowser(url) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .font(.callout)
                }
            }
        }
        .padding(14)
        .frame(width: 340)
        .preferredColorScheme(.dark)
    }

    private var top: [DeveloperProcess] {
        processesRanked.prefix(5).map { $0 }
    }

    private var processesRanked: [DeveloperProcess] {
        model.processes
            .filter { $0.runtime.isDeveloperFacing && !$0.isSystem }
            .sorted { $0.process.cpuPercent > $1.process.cpuPercent }
    }

    private var ports: [PortRow] {
        var rows: [PortRow] = []
        for process in processesRanked {
            for binding in process.listeningPorts {
                rows.append(PortRow(binding: binding, process: process))
            }
        }
        return rows.sorted { $0.binding.localPort < $1.binding.localPort }
    }
}
#endif
