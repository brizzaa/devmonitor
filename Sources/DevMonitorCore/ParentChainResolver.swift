import Foundation

public struct ParentChainResolver: Sendable {
    private let classifier: LauncherClassifier

    public init(classifier: LauncherClassifier = LauncherClassifier()) {
        self.classifier = classifier
    }

    public func resolve(pid: Int32, processes: [ProcessRecord]) -> ParentChain {
        let byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var ancestors: [Ancestor] = []
        var seen = Set<Int32>()
        var current = pid
        var depth = 0
        while depth < 16, let process = byPID[current], seen.insert(current).inserted {
            let parentPID = process.ppid
            guard parentPID > 0, parentPID != current, let parent = byPID[parentPID] else { break }
            if !seen.contains(parentPID) {
                ancestors.append(
                    Ancestor(
                        pid: parent.pid,
                        name: parent.name,
                        command: parent.command,
                        kind: classifier.classify(name: parent.name, command: parent.command)
                    )
                )
            }
            current = parentPID
            depth += 1
            if parentPID == 1 { break }
        }

        let links = displayLinks(ancestors: ancestors)
        // Outermost environment (iTerm around tmux, Cursor around zsh), else the shell.
        let launcher = links.first(where: { $0.kind.isEnvironment })?.kind
            ?? links.first(where: { $0.kind.isShell })?.kind
            ?? .unknown
        let summary = links.map(\.label).joined(separator: " → ")
        return ParentChain(ancestors: ancestors, links: links, launcher: launcher, summary: summary)
    }

    /// Outermost useful ancestor first. launchd is dropped. Consecutive helpers
    /// that share a label (Cursor + Cursor Helper) collapse into one step.
    /// The immediate parent is kept even when it is an ordinary tool such as npm.
    private func displayLinks(ancestors: [Ancestor]) -> [ChainLink] {
        guard !ancestors.isEmpty else { return [] }
        let immediate = ancestors[0]
        var selected: [Ancestor] = []
        for ancestor in ancestors.reversed() {
            if ancestor.kind == .launchd { continue }
            let keep = ancestor.kind.isEnvironment || ancestor.kind.isShell || ancestor.pid == immediate.pid
            if keep { selected.append(ancestor) }
        }
        var links: [ChainLink] = []
        for ancestor in selected {
            let label = ancestor.kind == .unknown ? ancestor.name : ancestor.kind.label
            if links.last?.label == label { continue }
            links.append(ChainLink(pid: ancestor.pid, label: label, command: ancestor.command, kind: ancestor.kind))
        }
        return links
    }
}
