#if os(macOS)
import SwiftUI
import DevMonitorCore

struct ProcessTreeView: View {
    var processes: [DeveloperProcess]
    @Environment(AppModel.self) private var model

    var body: some View {
        let nodes = forest(ProcessTreeBuilder().roots(from: processes))
        if nodes.isEmpty {
            EmptyPanel(
                title: "No process tree",
                systemImage: "arrow.triangle.branch",
                message: "Nothing in the current filter has a parent or child to draw."
            )
        } else {
            List(selection: selection) {
                OutlineGroup(nodes, children: \.children) { node in
                    HStack(spacing: 8) {
                        RuntimeBadge(runtime: node.process.runtime)
                        Text(node.process.process.name)
                            .fontWeight(node.process.runtime.isDeveloperFacing ? .semibold : .regular)
                        Text("\(node.process.id)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Theme.quiet)
                        Text(String(format: "%.1f%%", node.process.process.cpuPercent))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Theme.cyan)
                        if !node.process.listeningPortNumbers.isEmpty {
                            Text(ProcessFormatting.portSummary(node.process))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.quiet)
                        }
                    }
                    .tag(node.process.id)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private var selection: Binding<Int32?> {
        Binding(
            get: { model.selectedPID },
            set: { model.selectedPID = $0 }
        )
    }

    private func forest(_ nodes: [ProcessTreeNode]) -> [OutlineNode] {
        nodes.map { node in
            OutlineNode(
                process: node.process,
                children: node.children.isEmpty ? nil : forest(node.children)
            )
        }
    }
}

private struct OutlineNode: Identifiable, Hashable {
    var process: DeveloperProcess
    var children: [OutlineNode]?
    var id: Int32 { process.id }
}
#endif
