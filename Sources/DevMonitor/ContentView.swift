#if os(macOS)
import SwiftUI
import DevMonitorCore

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("hideSystem") private var hideSystem = true
    @AppStorage("showEstablished") private var showEstablished = false
    @AppStorage("groupByProject") private var groupByProject = false
    @State private var selection: SidebarItem? = .all
    @State private var sortOrder = [KeyPathComparator(\DeveloperProcess.cpuSort, order: .reverse)]

    private let catalog = ProcessCatalog()

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView(selection: $selection, groups: sidebarGroups)
        } content: {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if !model.warnings.isEmpty {
                        WarningBanner(text: model.warnings.joined(separator: " ")) {
                            model.dismissWarnings()
                        }
                    }
                    if selection != .docker {
                        DashboardHeader(
                            stats: model.dashboard,
                            cpuHistory: model.hostCPU.samples,
                            memoryHistory: model.hostMemory.samples,
                            totals: model.projectTotals
                        ) { total in
                            selection = .project(ProjectRef(isUnassigned: total.isUnassigned, name: total.name))
                        }
                    }
                    contentBody
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let flash = model.flashMessage {
                    Text(flash)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background { StudioBackground() }
            .animation(.easeOut(duration: 0.2), value: model.flashMessage)
            .navigationTitle(title)
            .searchable(text: $model.searchText, placement: .toolbar, prompt: "Name, command, port, project, or PID")
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                statusBar
            }
        } detail: {
            if let process = selectedProcess {
                ProcessDetailView(process: process)
            } else {
                ContentUnavailableView(
                    "No process selected",
                    systemImage: "sidebar.right",
                    description: Text("Select a process to see its working directory, project, parent chain, and ports.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .tint(Theme.cyan)
        .confirmationDialog(
            model.pendingKill?.title ?? "Terminate process?",
            isPresented: Binding(
                get: { model.pendingKill != nil },
                set: { if !$0 { model.pendingKill = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Send SIGTERM", role: .destructive) {
                model.confirmKill(signal: .term)
            }
            Button("Force Quit (SIGKILL)", role: .destructive) {
                model.confirmKill(signal: .kill)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.pendingKill?.message ?? "")
        }
        .alert(
            "Could not terminate process",
            isPresented: Binding(
                get: { model.killError != nil },
                set: { if !$0 { model.killError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.killError = nil }
        } message: {
            Text(model.killError ?? "")
        }
        .task { model.start() }
    }

    @ViewBuilder
    private var contentBody: some View {
        if model.isLoading && model.processes.isEmpty {
            ProgressView("Reading processes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selection == .ports {
            PortRadarView(rows: portRows)
        } else if selection == .tree {
            ProcessTreeView(processes: visible)
        } else if selection == .orphans {
            OrphanView(orphans: catalog.filtered(model.orphans, query: ProcessQuery(searchText: model.searchText)))
        } else if selection == .docker {
            DockerView(result: model.docker)
        } else if visible.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if groupByProject {
            GroupedProcessList(groups: catalog.groupedByProject(visible))
        } else {
            ProcessTableView(rows: visible, cpuSeries: { model.cpuSeries(for: $0) }, sortOrder: $sortOrder)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Toggle(isOn: $hideSystem) {
                Label("Hide system", systemImage: "eye.slash")
            }
            .toggleStyle(.button)
            .help("Hide macOS system processes. Recognised dev runtimes stay visible even if they run as root.")

            Toggle(isOn: $groupByProject) {
                Label("Group", systemImage: "square.grid.2x2")
            }
            .toggleStyle(.button)
            .disabled(selection == .ports || selection == .tree || selection == .orphans || selection == .docker)
            .help("Group rows by project. The current sort order is kept inside each group.")

            Toggle(isOn: $showEstablished) {
                Label("Established", systemImage: "arrow.left.arrow.right")
            }
            .toggleStyle(.button)
            .help("Also show established TCP connections. Listening ports are always shown.")

            Button {
                model.refreshNow()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh now. The list also refreshes about every 2 seconds.")

            Button {
                model.askKillSelected(signal: .term)
            } label: {
                Label("Terminate", systemImage: "xmark.circle")
            }
            .disabled(model.selectedPID == nil)
            .help("SIGTERM the selected process, after confirmation. ⌘⌫")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if selection == .ports {
                Text("\(portRows.count) sockets")
            } else {
                Text("\(visible.count) shown")
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("\(visible.filter(\.runtime.isDeveloperFacing).count) dev runtimes")
            }
            Spacer()
            if let updated = model.lastUpdated {
                HStack(spacing: 4) {
                    Text("Updated")
                    Text(updated, style: .relative)
                }
            } else {
                Text("Waiting for the first snapshot")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if hideSystem && !model.processes.isEmpty {
            ContentUnavailableView(
                "Only system processes are running",
                systemImage: "eye.slash",
                description: Text("Turn off Hide system to see launchd, WindowServer, and the rest of macOS.")
            )
        } else if !model.warnings.isEmpty {
            ContentUnavailableView(
                "No process list",
                systemImage: "exclamationmark.triangle",
                description: Text(model.warnings.joined(separator: " "))
            )
        } else {
            ContentUnavailableView(
                "No processes",
                systemImage: "list.bullet",
                description: Text("ps did not return any processes.")
            )
        }
    }

    private var title: String {
        switch selection {
        case .all, .none: return "All processes"
        case .developer: return "Developer runtimes"
        case .ports: return "Port radar"
        case .tree: return "Process tree"
        case .orphans: return "Detached"
        case .docker: return "Docker"
        case .project(let ref): return ref.isUnassigned ? "No project" : ref.name
        }
    }

    private var selectedProcess: DeveloperProcess? {
        guard let pid = model.selectedPID else { return nil }
        return model.process(pid: pid)
    }

    private var baseProcesses: [DeveloperProcess] {
        catalog.filtered(
            model.processes,
            query: ProcessQuery(
                searchText: model.searchText,
                hideSystem: hideSystem,
                developerRuntimesOnly: selection == .developer
            )
        )
    }

    private var sidebarGroups: [ProjectGroup] {
        catalog.groupedByProject(baseProcesses)
    }

    private var visible: [DeveloperProcess] {
        let filtered = catalog.filtered(baseProcesses, query: ProcessQuery(projectFilter: projectFilter))
        return filtered.sorted(using: sortOrder)
    }

    private var projectFilter: ProjectFilter {
        guard case .project(let ref) = selection else { return .all }
        return ref.isUnassigned ? .unassigned : .named(ref.name)
    }

    private var portRows: [PortRow] {
        let query = model.portQuery.trimmingCharacters(in: .whitespaces)
        let source = catalog.filtered(
            model.processes,
            query: ProcessQuery(searchText: model.searchText, hideSystem: hideSystem)
        )
        var rows: [PortRow] = []
        for process in source {
            for binding in process.ports {
                if !showEstablished && binding.state != .listen { continue }
                if !query.isEmpty && !String(binding.localPort).hasPrefix(query) { continue }
                rows.append(PortRow(binding: binding, process: process))
            }
        }
        return rows.sorted { lhs, rhs in
            if lhs.binding.localPort != rhs.binding.localPort {
                return lhs.binding.localPort < rhs.binding.localPort
            }
            return lhs.process.id < rhs.process.id
        }
    }
}
#endif
