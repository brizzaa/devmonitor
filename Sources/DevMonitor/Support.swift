#if os(macOS)
import AppKit
import SwiftUI
import DevMonitorCore

enum Clipboard {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

enum Finder {
    static func reveal(_ path: String) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        guard exists else { return }
        if isDirectory.boolValue {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
}

extension DevRuntime {
    var tint: Color {
        switch self {
        case .node: return Color(red: 0.13, green: 0.55, blue: 0.32)
        case .bun: return Color(red: 0.78, green: 0.48, blue: 0.12)
        case .deno: return Color(red: 0.16, green: 0.42, blue: 0.72)
        case .python: return Color(red: 0.18, green: 0.38, blue: 0.70)
        case .ruby: return Color(red: 0.76, green: 0.20, blue: 0.26)
        case .java: return Color(red: 0.82, green: 0.42, blue: 0.10)
        case .go: return Color(red: 0.00, green: 0.55, blue: 0.62)
        case .rust: return Color(red: 0.70, green: 0.34, blue: 0.16)
        case .swift: return Color(red: 0.86, green: 0.32, blue: 0.20)
        case .docker: return Color(red: 0.08, green: 0.46, blue: 0.78)
        case .postgres: return Color(red: 0.20, green: 0.38, blue: 0.58)
        case .redis: return Color(red: 0.78, green: 0.16, blue: 0.20)
        case .mysql: return Color(red: 0.00, green: 0.42, blue: 0.55)
        case .mongo: return Color(red: 0.16, green: 0.52, blue: 0.34)
        case .nginx: return Color(red: 0.12, green: 0.50, blue: 0.30)
        case .php: return Color(red: 0.42, green: 0.42, blue: 0.72)
        case .beam: return Color(red: 0.50, green: 0.26, blue: 0.60)
        case .dotnet: return Color(red: 0.36, green: 0.30, blue: 0.70)
        case .kubernetes: return Color(red: 0.18, green: 0.40, blue: 0.78)
        case .unknown: return Color.secondary
        }
    }
}

extension DeveloperProcess {
    var pidSort: Int32 { process.pid }
    var nameSort: String { process.name.lowercased() }
    var cpuSort: Double { process.cpuPercent }
    var memorySort: UInt64 { process.memoryBytes }
    var userSort: String { process.user.lowercased() }
    var startSort: Date { process.startTime }
    var uptimeSort: TimeInterval { process.elapsedSeconds }
    var commandSort: String { process.command.lowercased() }
    var projectSort: String { project?.projectName?.lowercased() ?? "\u{10FFFF}" }
    var portSort: Int { listeningPortNumbers.first ?? Int.max }
}

enum ProcessFormatting {
    static func portSummary(_ process: DeveloperProcess) -> String {
        let ports = process.listeningPortNumbers
        if ports.isEmpty { return "—" }
        let shown = ports.prefix(3).map(String.init).joined(separator: ", ")
        if ports.count > 3 { return "\(shown) +\(ports.count - 3)" }
        return shown
    }

    static func endpoint(_ binding: PortBinding) -> String {
        var text = "\(binding.localAddress):\(binding.localPort)"
        if let remoteAddress = binding.remoteAddress, let remotePort = binding.remotePort {
            text += " → \(remoteAddress):\(remotePort)"
        }
        return text
    }
}

struct RuntimeBadge: View {
    var runtime: DevRuntime

    var body: some View {
        if runtime.isDeveloperFacing {
            HStack(spacing: 4) {
                Image(systemName: runtime.symbolName)
                    .font(.caption2.weight(.bold))
                Text(runtime.label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(runtime.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(runtime.tint.opacity(0.16), in: Capsule())
            .accessibilityLabel("Runtime \(runtime.label)")
        }
    }
}

struct WarningBanner: View {
    var text: String
    var dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button("Dismiss", action: dismiss)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.14))
    }
}
#endif
