#if os(macOS)
import SwiftUI
import DevMonitorCore

struct PortRadarView: View {
    var rows: [PortRow]
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Theme.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Port radar")
                        .font(.headline)
                    Text("Every listening socket. Open it in the browser, or silence it.")
                        .font(.callout)
                        .foregroundStyle(Theme.quiet)
                }
                Spacer()
                TextField("Filter port", text: $model.portQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .font(.title3.monospacedDigit())
            }
            .padding(.horizontal, 16)

            if rows.isEmpty {
                EmptyPanel(
                    title: model.portQuery.isEmpty ? "No listening ports" : "Nothing on that port",
                    systemImage: "network.slash",
                    message: model.portQuery.isEmpty
                        ? "lsof did not report sockets for the processes you can see."
                        : "No local port starts with \(model.portQuery). Clients of a remote server are not listed."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 196), spacing: 12)], spacing: 12) {
                        ForEach(rows) { row in
                            PortRadarCard(row: row)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

private struct PortRadarCard: View {
    var row: PortRow
    @Environment(AppModel.self) private var model

    var body: some View {
        let binding = row.binding
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(binding.localPort)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                Spacer()
                Text(binding.transport.rawValue.uppercased())
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(Theme.quiet)
            }
            RuntimeBadge(runtime: row.process.runtime)
            Text(row.process.process.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(row.process.project?.projectName ?? binding.localAddress)
                .font(.caption)
                .foregroundStyle(Theme.quiet)
                .lineLimit(1)
            HStack(spacing: 8) {
                if binding.transport == .tcp, let url = LocalHTTPURL.url(address: binding.localAddress, port: binding.localPort) {
                    Button {
                        WorkspaceOpener.openInBrowser(url)
                    } label: {
                        Label("Open", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.cyan.opacity(0.85))
                }
                Button {
                    model.quickTerminate(pid: row.process.id)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                Button {
                    model.toggleWatch(port: binding.localPort)
                } label: {
                    Image(systemName: model.watchedPorts.contains(binding.localPort) ? "bell.fill" : "bell")
                }
                .buttonStyle(.borderless)
                .help("Notify when this port is freed")
            }
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [row.process.runtime.tint.opacity(0.22), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(row.process.runtime.tint.opacity(0.35), lineWidth: 1)
        )
        .onTapGesture {
            model.selectedPID = row.process.id
        }
    }
}
#endif
