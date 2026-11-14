#if os(macOS)
import Foundation
import Observation
import UserNotifications
import DevMonitorCore

struct PendingKill: Identifiable {
    var id = UUID()
    var pids: [Int32]
    var title: String
    var message: String
}

final class UserNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UserNotifier()

    func prepare() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Snapshot, history, watches, and kill actions. Filtering lives in the views.
@MainActor
@Observable
final class AppModel {
    private(set) var processes: [DeveloperProcess] = []
    private(set) var cpuStore = ProcessMetricStore(capacity: 24)
    private(set) var hostCPU = MetricHistory(capacity: 36)
    private(set) var hostMemory = MetricHistory(capacity: 36)
    private(set) var docker = DockerLoadResult.unavailable
    var warnings: [String] = []
    var isLoading = true
    var lastUpdated: Date?
    var searchText = ""
    var portQuery = ""
    var selectedPID: Int32?
    var pendingKill: PendingKill?
    var killError: String?
    var flashMessage: String?
    var watchedPIDs: Set<Int32> = []
    var watchedPorts: Set<Int> = []

    private let loader: LiveSnapshotLoader
    private let dockerLoader: DockerSnapshotLoader
    private let killer: KillService
    private let orphansDetector = OrphanDetector()
    private var loopTask: Task<Void, Never>?
    private var loadInFlight = false
    private var queued = false
    private var hasSnapshot = false

    init(
        loader: LiveSnapshotLoader = LiveSnapshotLoader(
            runner: FoundationCommandRunner(),
            detector: ProjectDetector(probe: LocalFileSystem())
        ),
        dockerLoader: DockerSnapshotLoader = DockerSnapshotLoader(runner: FoundationCommandRunner()),
        killer: KillService = KillService(signaler: SystemProcessSignaler())
    ) {
        self.loader = loader
        self.dockerLoader = dockerLoader
        self.killer = killer
        if let stored = UserDefaults.standard.array(forKey: Keys.pids) as? [Int] {
            watchedPIDs = Set(stored.compactMap { Int32(exactly: $0) })
        }
        if let stored = UserDefaults.standard.array(forKey: Keys.ports) as? [Int] {
            watchedPorts = Set(stored)
        }
    }

    var dashboard: DashboardStats { DashboardStats.make(from: processes) }

    var projectTotals: [ProjectResourceTotal] { ProjectTotals.summarize(processes) }

    var orphans: [DeveloperProcess] { orphansDetector.orphans(in: processes) }

    func cpuSeries(for pid: Int32) -> [Double] { cpuStore.series(for: pid) }

    func start() {
        guard loopTask == nil else { return }
        UserNotifier.shared.prepare()
        loopTask = Task {
            while !Task.isCancelled {
                await self.loadOnce()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func refreshNow() {
        Task { await loadOnce() }
    }

    func dismissWarnings() {
        warnings = []
    }

    func process(pid: Int32) -> DeveloperProcess? {
        processes.first { $0.id == pid }
    }

    func toggleWatch(pid: Int32) {
        var next = watchedPIDs
        if next.contains(pid) {
            next.remove(pid)
        } else {
            next.insert(pid)
        }
        watchedPIDs = next
        UserDefaults.standard.set(next.map { Int($0) }, forKey: Keys.pids)
    }

    func toggleWatch(port: Int) {
        var next = watchedPorts
        if next.contains(port) {
            next.remove(port)
        } else {
            next.insert(port)
        }
        watchedPorts = next
        UserDefaults.standard.set(Array(next), forKey: Keys.ports)
    }

    func askKillSelected(signal: KillSignal) {
        guard let selectedPID else { return }
        askKill(pid: selectedPID, signal: signal)
    }

    func askKill(pid: Int32, signal: KillSignal) {
        guard let process = process(pid: pid) else { return }
        askKill(processes: [process], signal: signal, title: nil)
    }

    func askKill(processes list: [DeveloperProcess], signal: KillSignal, title: String?) {
        guard !list.isEmpty else { return }
        let verb = signal == .kill ? "Force quit" : "Terminate"
        let heading = title ?? "\(verb) \(list[0].process.name)?"
        pendingKill = PendingKill(pids: list.map(\.id), title: heading, message: describe(list))
    }

    func askKill(port: Int, signal: KillSignal) {
        var seen = Set<Int32>()
        var matches: [DeveloperProcess] = []
        for process in processes where process.ports.contains(where: { $0.localPort == port }) {
            if seen.insert(process.id).inserted {
                matches.append(process)
            }
        }
        let verb = signal == .kill ? "Force quit" : "Terminate"
        askKill(processes: matches, signal: signal, title: "\(verb) whatever is on port \(port)?")
    }

    /// Menu bar action: SIGTERM immediately, then surface permission errors.
    func quickTerminate(pid: Int32) {
        switch killer.kill(pid: pid, signal: .term) {
        case .sent:
            flash("Sent SIGTERM to \(pid)")
            refreshNow()
        case .failed(let error):
            killError = error.userMessage
        }
    }

    func confirmKill(signal: KillSignal) {
        guard let pending = pendingKill else { return }
        pendingKill = nil
        var failures: [String] = []
        for pid in pending.pids {
            if case .failed(let error) = killer.kill(pid: pid, signal: signal) {
                failures.append(error.userMessage)
            }
        }
        if failures.isEmpty {
            flash(signal == .kill ? "Sent SIGKILL" : "Sent SIGTERM")
        } else {
            killError = failures.joined(separator: "\n\n")
        }
        refreshNow()
    }

    func flash(_ message: String) {
        flashMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if flashMessage == message {
                flashMessage = nil
            }
        }
    }

    private func describe(_ processes: [DeveloperProcess]) -> String {
        let lines = processes.prefix(8).map { process -> String in
            let command = process.process.command
            let trimmed = command.count > 140 ? String(command.prefix(140)) + "…" : command
            return "• \(process.process.name) (\(process.process.pid)) — \(trimmed)"
        }
        var text = lines.joined(separator: "\n")
        if processes.count > 8 {
            text += "\n• and \(processes.count - 8) more"
        }
        text += "\n\nSIGTERM asks the process to exit and is the one to try first. Force Quit sends SIGKILL, which cannot be caught. macOS refuses the signal when you do not own the process."
        return text
    }

    private func loadOnce() async {
        if loadInFlight {
            queued = true
            return
        }
        loadInFlight = true
        defer { loadInFlight = false }
        repeat {
            queued = false
            let loader = self.loader
            let dockerLoader = self.dockerLoader
            let snapshotTask = Task.detached(priority: .userInitiated) {
                loader.load(now: Date())
            }
            let dockerTask = Task.detached(priority: .userInitiated) {
                dockerLoader.load()
            }
            let result = await snapshotTask.value
            let dockerResult = await dockerTask.value
            if Task.isCancelled { return }
            apply(result, docker: dockerResult)
        } while queued && !Task.isCancelled
    }

    private func apply(_ result: SnapshotLoadResult, docker dockerResult: DockerLoadResult) {
        let previous = processes
        let hadSnapshot = hasSnapshot
        if hadSnapshot {
            noteDepartures(from: previous, to: result.processes)
        }
        processes = result.processes
        cpuStore.record(result.processes)
        let stats = DashboardStats.make(from: result.processes)
        hostCPU.append(stats.developerCPU)
        hostMemory.append(Double(stats.developerMemory))
        docker = dockerResult
        warnings = result.warnings
        isLoading = false
        lastUpdated = Date()
        hasSnapshot = true
        if let selectedPID, process(pid: selectedPID) == nil {
            self.selectedPID = nil
        }
    }

    private func noteDepartures(from previous: [DeveloperProcess], to next: [DeveloperProcess]) {
        let stillAlive = Set(next.map(\.id))
        var droppedPIDs = watchedPIDs
        for process in previous where watchedPIDs.contains(process.id) && !stillAlive.contains(process.id) {
            UserNotifier.shared.post(
                title: "\(process.process.name) stopped",
                body: "Watched PID \(process.id) is no longer running."
            )
            droppedPIDs.remove(process.id)
        }
        if droppedPIDs != watchedPIDs {
            watchedPIDs = droppedPIDs
            UserDefaults.standard.set(droppedPIDs.map { Int($0) }, forKey: Keys.pids)
        }

        let previousPorts = Set(previous.flatMap(\.listeningPortNumbers))
        let nextPorts = Set(next.flatMap(\.listeningPortNumbers))
        var droppedPorts = watchedPorts
        for port in watchedPorts where previousPorts.contains(port) && !nextPorts.contains(port) {
            UserNotifier.shared.post(
                title: "Port \(port) is free",
                body: "Nothing is listening on local port \(port) anymore."
            )
            droppedPorts.remove(port)
        }
        if droppedPorts != watchedPorts {
            watchedPorts = droppedPorts
            UserDefaults.standard.set(Array(droppedPorts), forKey: Keys.ports)
        }
    }

    private enum Keys {
        static let pids = "watchedPIDs"
        static let ports = "watchedPorts"
    }
}
#endif
