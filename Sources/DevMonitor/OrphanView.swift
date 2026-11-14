#if os(macOS)
import SwiftUI
import DevMonitorCore

struct OrphanView: View {
    var orphans: [DeveloperProcess]
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detached dev servers")
                        .font(.headline)
                    Text("Session runtimes with no terminal, IDE, or shell left in the parent chain. Databases and Docker are not included.")
                        .font(.callout)
                        .foregroundStyle(Theme.quiet)
                }
                Spacer()
                Button("Clean up") {
                    model.askKill(
                        processes: orphans,
                        signal: .term,
                        title: "Terminate \(orphans.count) detached process\(orphans.count == 1 ? "" : "es")?"
                    )
                }
                .disabled(orphans.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(Theme.amber)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if orphans.isEmpty {
                EmptyPanel(
                    title: "No strays",
                    systemImage: "checkmark.seal",
                    message: "Every Node, Python, Ruby, Java, Go, and similar process still has a shell or editor above it."
                )
            } else {
                List(selection: selection) {
                    ForEach(orphans) { process in
                        HStack(spacing: 10) {
                            RuntimeBadge(runtime: process.runtime)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(process.process.name)
                                    .fontWeight(.semibold)
                                Text(process.process.command)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Theme.quiet)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text("\(process.id)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(Theme.quiet)
                            Text(ProcessFormatting.portSummary(process))
                                .font(.callout.monospacedDigit())
                        }
                        .tag(process.id)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var selection: Binding<Int32?> {
        Binding(get: { model.selectedPID }, set: { model.selectedPID = $0 })
    }
}
#endif
