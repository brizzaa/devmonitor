import Foundation

public struct LauncherClassifier: Sendable {
    public init() {}

    public func classify(name: String, command: String) -> LauncherKind {
        let base = normalized(name)
        let commandText = command.lowercased()

        if base == "launchd" || commandText.contains("/sbin/launchd") { return .launchd }
        if base.contains("iterm") || commandText.contains("iterm.app") { return .iterm }
        if base == "terminal" || commandText.contains("terminal.app") { return .terminal }
        if base == "warp" || commandText.contains("warp.app") { return .warp }
        if base.contains("ghostty") || commandText.contains("ghostty.app") { return .ghostty }
        if base == "kitty" || commandText.contains("kitty.app") { return .kitty }
        if base.contains("alacritty") { return .alacritty }
        if base.contains("wezterm") { return .wezterm }
        // Cursor is a VS Code fork. Match it before the generic "Code" rules.
        if base == "cursor" || base.hasPrefix("cursor helper") || commandText.contains("cursor.app") {
            return .cursor
        }
        if base == "code"
            || base.hasPrefix("code helper")
            || commandText.contains("visual studio code.app")
            || commandText.contains("/code.app/") {
            return .vscode
        }
        if base == "tmux" || base.hasPrefix("tmux:") { return .tmux }
        if base == "zsh" { return .zsh }
        if base == "bash" { return .bash }
        if base == "fish" { return .fish }
        if base == "sh" || base == "dash" { return .sh }
        if jetBrainsNames.contains(base) || commandText.contains("jetbrains") { return .jetbrains }
        if base == "xcode" || base == "xcodebuild" || commandText.contains("xcode.app") { return .xcode }
        if base == "zed" || commandText.contains("zed.app") { return .zed }
        if base.contains("sublime") { return .sublime }
        if base == "emacs" { return .emacs }
        if base == "vim" || base == "nvim" || base == "vi" { return .vim }
        if base.contains("docker") || base == "containerd" || base == "colima" { return .docker }
        return .unknown
    }

    private func normalized(_ name: String) -> String {
        var value = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("-"), value.count > 1 { value.removeFirst() }
        return value
    }

    private var jetBrainsNames: Set<String> {
        ["idea", "webstorm", "pycharm", "goland", "phpstorm", "rubymine", "clion", "datagrip", "rider", "rustrover"]
    }
}
