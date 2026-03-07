import Foundation

enum ProcessClassifier {
    static let customHintsDefaultsKey = "trustedAncestorHints"

    private static let trustedExecutableNames: Set<String> = [
        "sh", "bash", "zsh", "fish", "ksh", "tcsh", "csh", "dash", "nu", "pwsh", "tmux", "screen",
        "codex", "aider", "claude", "opencode", "goose", "continue", "cline", "roo", "qodo"
    ]

    private static let trustedPhraseHints = [
        "terminal", "iterm", "wezterm", "warp", "alacritty", "kitty", "ghostty", "hyper",
        "visual studio code", "code helper", "cursor", "windsurf", "zed", "xcode", "jetbrains",
        "intellij", "pycharm", "webstorm", "goland", "rubymine", "clion", "android studio",
        "conductor", "claude code", "cline", "roo code", "aider", "codex", "gemini-cli",
        "opencode", "openhands", "continue.dev"
    ]

    private static let trustedTokenHints: Set<String> = [
        "terminal", "iterm2", "wezterm", "warp", "alacritty", "kitty", "ghostty", "hyper",
        "cursor", "windsurf", "zed", "xcode", "jetbrains", "intellij", "pycharm", "webstorm",
        "goland", "rubymine", "clion", "conductor", "codex", "aider", "claude", "cline",
        "roo", "goose", "opencode", "openhands", "continue", "gemini", "qodo"
    ]

    static func isTrustedAncestorCommand(_ command: String) -> Bool {
        let lower = command.lowercased()
        let component = URL(fileURLWithPath: lower).lastPathComponent
        if trustedExecutableNames.contains(component) {
            return true
        }

        let tokens = Set(
            lower
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
        )
        if !tokens.isDisjoint(with: trustedTokenHints) {
            return true
        }

        let customHints = UserDefaults.standard.stringArray(forKey: customHintsDefaultsKey) ?? []
        if customHints.contains(where: { hint in
            let normalized = hint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !normalized.isEmpty && lower.contains(normalized)
        }) {
            return true
        }

        return trustedPhraseHints.contains(where: { lower.contains($0) })
    }
}
