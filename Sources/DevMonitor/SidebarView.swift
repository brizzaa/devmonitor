#if os(macOS)
import SwiftUI
import DevMonitorCore

struct ProjectRef: Hashable {
    var isUnassigned: Bool
    var name: String
}

enum SidebarItem: Hashable {
    case all
    case developer
    case ports
    case tree
    case orphans
    case docker
    case project(ProjectRef)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    var groups: [ProjectGroup]

    var body: some View {
        List(selection: $selection) {
            Section("Monitor") {
                Label("All processes", systemImage: "list.bullet")
                    .tag(SidebarItem.all)
                Label("Developer runtimes", systemImage: "hammer")
                    .tag(SidebarItem.developer)
                Label("Port radar", systemImage: "dot.radiowaves.left.and.right")
                    .tag(SidebarItem.ports)
                Label("Process tree", systemImage: "arrow.triangle.branch")
                    .tag(SidebarItem.tree)
                Label("Detached", systemImage: "exclamationmark.triangle")
                    .tag(SidebarItem.orphans)
                Label("Docker", systemImage: "shippingbox")
                    .tag(SidebarItem.docker)
            }
            Section("Projects") {
                if groups.isEmpty {
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { group in
                        HStack(spacing: 8) {
                            Image(systemName: group.isUnassigned ? "questionmark.folder" : "folder")
                                .foregroundStyle(.secondary)
                            Text(group.name)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(group.processes.count)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.project(ProjectRef(isUnassigned: group.isUnassigned, name: group.name)))
                        .accessibilityLabel("\(group.name), \(group.processes.count) processes")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 320)
    }
}
#endif
