#if os(macOS)
import SwiftUI

@main
struct DevMonitorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .defaultSize(width: 1360, height: 860)
        .commands {
            CommandMenu("Process") {
                Button("Terminate…") {
                    model.askKillSelected(signal: .term)
                }
                .keyboardShortcut(.delete, modifiers: .command)
                Button("Force Quit…") {
                    model.askKillSelected(signal: .kill)
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
                Divider()
                Button("Refresh") {
                    model.refreshNow()
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Watch Process") {
                    if let pid = model.selectedPID {
                        model.toggleWatch(pid: pid)
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Copy Command") {
                    if let pid = model.selectedPID, let process = model.process(pid: pid) {
                        Clipboard.copy(process.process.command)
                        model.flash("Copied command")
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarDashboard()
                .environment(model)
        } label: {
            Image(systemName: "waveform.path.ecg")
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
