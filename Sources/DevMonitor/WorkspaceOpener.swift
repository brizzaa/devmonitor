#if os(macOS)
import AppKit
import Foundation
import DevMonitorCore

enum WorkspaceOpener {
    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func openInTerminal(commandLine: String) -> String? {
        let source = """
        tell application "Terminal"
            activate
            do script \(appleScriptString(commandLine))
        end tell
        """
        return runAppleScript(source)
    }

    static func openInEditor(path: String, candidates: [String]) -> String? {
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        for candidate in candidates {
            let expanded = (candidate as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                [folder],
                withApplicationAt: URL(fileURLWithPath: expanded),
                configuration: configuration
            )
            return nil
        }
        return "Could not find \(candidates.first ?? "the editor"). Install it in /Applications, or open the folder from Finder."
    }

    static let cursorCandidates = [
        "/Applications/Cursor.app",
        "~/Applications/Cursor.app",
    ]

    static let vsCodeCandidates = [
        "/Applications/Visual Studio Code.app",
        "~/Applications/Visual Studio Code.app",
    ]

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return "Could not build the Terminal script."
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let message = error?.object(forKey: "NSAppleScriptErrorMessage") as? String, !message.isEmpty {
            return message
        }
        return nil
    }
}
#endif
