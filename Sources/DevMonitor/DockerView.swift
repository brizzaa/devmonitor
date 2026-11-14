#if os(macOS)
import SwiftUI
import DevMonitorCore

struct DockerView: View {
    var result: DockerLoadResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Docker")
                        .font(.headline)
                    Text(result.available ? "Containers reported by docker ps." : "The docker CLI is not available on PATH.")
                        .font(.callout)
                        .foregroundStyle(Theme.quiet)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let warning = result.warning {
                Text(warning)
                    .font(.callout)
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 16)
            }

            if !result.available {
                EmptyPanel(
                    title: "Docker not installed",
                    systemImage: "shippingbox",
                    message: "Install Docker Desktop or the docker CLI and DevMonitor will list running containers here."
                )
            } else if result.containers.isEmpty {
                EmptyPanel(
                    title: "No containers",
                    systemImage: "shippingbox",
                    message: result.warning == nil ? "docker ps returned an empty list." : "Docker did not return any containers."
                )
            } else {
                List(result.containers) { container in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(container.name)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text(container.state.isEmpty ? container.status : container.state)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(container.state == "running" ? Theme.cyan : Theme.quiet)
                        }
                        Text(container.image)
                            .font(.callout)
                            .foregroundStyle(Theme.quiet)
                        if !container.ports.isEmpty {
                            Text(container.ports)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        Text(container.status)
                            .font(.caption)
                            .foregroundStyle(Theme.quiet)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
#endif
