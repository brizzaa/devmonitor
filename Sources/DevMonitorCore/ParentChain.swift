import Foundation

public enum LauncherKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case iterm
    case terminal
    case vscode
    case cursor
    case tmux
    case zsh
    case bash
    case fish
    case sh
    case warp
    case ghostty
    case alacritty
    case kitty
    case wezterm
    case jetbrains
    case xcode
    case zed
    case sublime
    case emacs
    case vim
    case docker
    case launchd
    case unknown

    public var label: String {
        switch self {
        case .iterm: return "iTerm2"
        case .terminal: return "Terminal"
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .tmux: return "tmux"
        case .zsh: return "zsh"
        case .bash: return "bash"
        case .fish: return "fish"
        case .sh: return "sh"
        case .warp: return "Warp"
        case .ghostty: return "Ghostty"
        case .alacritty: return "Alacritty"
        case .kitty: return "kitty"
        case .wezterm: return "WezTerm"
        case .jetbrains: return "JetBrains"
        case .xcode: return "Xcode"
        case .zed: return "Zed"
        case .sublime: return "Sublime Text"
        case .emacs: return "Emacs"
        case .vim: return "Vim"
        case .docker: return "Docker"
        case .launchd: return "launchd"
        case .unknown: return "Unknown"
        }
    }

    public var isShell: Bool {
        switch self {
        case .zsh, .bash, .fish, .sh: return true
        default: return false
        }
    }

    /// A terminal, IDE, multiplexer, or container runtime — the thing a developer
    /// means by "what launched this", as opposed to the shell in between.
    public var isEnvironment: Bool {
        switch self {
        case .iterm, .terminal, .vscode, .cursor, .tmux, .warp, .ghostty,
             .alacritty, .kitty, .wezterm, .jetbrains, .xcode, .zed, .sublime,
             .emacs, .vim, .docker:
            return true
        case .zsh, .bash, .fish, .sh, .launchd, .unknown:
            return false
        }
    }
}

public struct Ancestor: Equatable, Hashable, Sendable, Identifiable {
    public var pid: Int32
    public var name: String
    public var command: String
    public var kind: LauncherKind

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, command: String, kind: LauncherKind) {
        self.pid = pid
        self.name = name
        self.command = command
        self.kind = kind
    }
}

/// A collapsed step in the launch chain, outermost environment first.
public struct ChainLink: Equatable, Hashable, Sendable, Identifiable {
    public var pid: Int32
    public var label: String
    public var command: String
    public var kind: LauncherKind

    public var id: Int32 { pid }

    public init(pid: Int32, label: String, command: String, kind: LauncherKind) {
        self.pid = pid
        self.label = label
        self.command = command
        self.kind = kind
    }
}

public struct ParentChain: Equatable, Hashable, Sendable {
    /// Immediate parent first, then its parent, up to launchd or a missing pid.
    public var ancestors: [Ancestor]
    /// Display order: the outermost terminal/IDE/shell first.
    public var links: [ChainLink]
    public var launcher: LauncherKind
    public var summary: String

    public init(ancestors: [Ancestor], links: [ChainLink], launcher: LauncherKind, summary: String) {
        self.ancestors = ancestors
        self.links = links
        self.launcher = launcher
        self.summary = summary
    }

    public static let none = ParentChain(ancestors: [], links: [], launcher: .unknown, summary: "")
}
