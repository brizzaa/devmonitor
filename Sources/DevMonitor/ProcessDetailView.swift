#if os(macOS)
import AppKit
import SwiftUI
import DevMonitorCore

struct ProcessDetailView: View {
    var process: DeveloperProcess
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                stats
                section("Command") {
                    selectableBlock(process.process.command, monospaced: true)
                    Button("Copy command") {
                        Clipboard.copy(process.process.command)
                    }
                    .buttonStyle(.borderless)
                }
                section("Project") { projectBody }
                section("Launched by") { parentBody }
                section("Ports") { portsBody }
                actions
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RuntimeBadge(runtime: process.runtime)
                if process.isSystem {
                    Text("System")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
            Text(process.process.name)
                .font(.title2.weight(.semibold))
            Text("PID \(process.process.pid) · \(process.process.user)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
            stat("CPU", String(format: "%.1f%%", process.process.cpuPercent))
            stat("Memory", ByteFormat.string(bytes: process.process.memoryBytes))
            stat("Uptime", UptimeFormat.string(seconds: process.process.elapsedSeconds))
            stat("Started", process.process.startTime.formatted(date: .abbreviated, time: .standard))
        }
    }

    private var projectBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            stat("Name", process.project?.projectName ?? "—")
            if let cwd = process.workingDirectory {
                labeledPath("Working directory", cwd)
            } else {
                Text("Working directory is not available. lsof could not read this process.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let root = process.project?.gitRoot {
                labeledPath("Git root", root)
            }
            if let kind = process.project?.manifestKind, let path = process.project?.manifestPath {
                labeledPath(kind.fileName, path)
            }
        }
    }

    private var parentBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if process.parents.links.isEmpty {
                Text("No terminal, IDE, or shell in the parent chain. This usually means launchd started it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(process.parents.links.enumerated()), id: \.element.id) { index, link in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(link.label)
                                .font(.callout.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                                .help("PID \(link.pid)\n\(link.command)")
                        }
                    }
                }
            }
            if !process.parents.ancestors.isEmpty {
                DisclosureGroup("Parent processes") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(process.parents.ancestors) { ancestor in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(ancestor.name) · \(ancestor.pid) · \(ancestor.kind.label)")
                                    .font(.callout.weight(.medium))
                                Text(ancestor.command)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.callout)
            }
        }
    }

    private var portsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if process.ports.isEmpty {
                Text("No TCP or UDP sockets reported for this process.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(process.ports) { binding in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(binding.transport.rawValue.uppercased())
                            .font(.caption.weight(.semibold).monospaced())
                            .frame(width: 36, alignment: .leading)
                        Text(binding.state.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 88, alignment: .leading)
                        Text(ProcessFormatting.endpoint(binding))
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Terminate…") {
                    model.askKill(pid: process.id, signal: .term)
                }
                .buttonStyle(.bordered)
                Button("Force Quit…") {
                    model.askKill(pid: process.id, signal: .kill)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                Button {
                    model.toggleWatch(pid: process.id)
                } label: {
                    Label(model.watchedPIDs.contains(process.id) ? "Watching" : "Watch", systemImage: model.watchedPIDs.contains(process.id) ? "star.fill" : "star")
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
                Button("Copy command") {
                    Clipboard.copy(process.process.command)
                    model.flash("Copied command")
                }
                Button("Copy restart") {
                    Clipboard.copy(restartLine)
                    model.flash("Copied restart command")
                }
                Button("Restart in Terminal") {
                    if let error = WorkspaceOpener.openInTerminal(commandLine: restartLine) {
                        model.killError = error
                    } else {
                        model.flash("Opened in Terminal")
                    }
                }
            }
            .buttonStyle(.bordered)
            if let cwd = process.workingDirectory {
                HStack(spacing: 8) {
                    Button("Finder") { Finder.reveal(cwd) }
                    Button("Terminal") {
                        if let error = WorkspaceOpener.openInTerminal(commandLine: RestartCommand.shellLine(command: "clear", workingDirectory: cwd)) {
                            model.killError = error
                        }
                    }
                    Button("Cursor") { openEditor(WorkspaceOpener.cursorCandidates) }
                    Button("VS Code") { openEditor(WorkspaceOpener.vsCodeCandidates) }
                }
                .buttonStyle(.bordered)
            }
            if let port = process.listeningPortNumbers.first,
               let binding = process.listeningPorts.first(where: { $0.localPort == port }),
               binding.transport == .tcp,
               let url = LocalHTTPURL.url(address: binding.localAddress, port: port) {
                Button("Open localhost:\(port)") {
                    WorkspaceOpener.openInBrowser(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.cyan)
            }
            Text("⌘⌫ terminate · ⌥⌘⌫ force quit. Both ask for confirmation. The menu bar can SIGTERM without a second dialog.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var restartLine: String {
        RestartCommand.shellLine(command: process.process.command, workingDirectory: process.workingDirectory)
    }

    private func openEditor(_ candidates: [String]) {
        guard let cwd = process.workingDirectory else { return }
        if let error = WorkspaceOpener.openInEditor(path: cwd, candidates: candidates) {
            model.killError = error
        } else {
            model.flash("Opened project folder")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
                .textSelection(.enabled)
        }
    }

    private func labeledPath(_ title: String, _ path: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            selectableBlock(path, monospaced: true)
            HStack(spacing: 12) {
                Button("Copy") { Clipboard.copy(path) }
                Button("Show in Finder") { Finder.reveal(path) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private func selectableBlock(_ text: String, monospaced: Bool) -> some View {
        Text(text)
            .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))
            )
    }
}
#endif
