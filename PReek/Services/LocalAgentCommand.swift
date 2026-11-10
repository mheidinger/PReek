#if os(macOS)
    import Foundation

    /// Two quoting layers: Ghostty's POSIX wrapper, then the user's login shell.
    enum LocalAgentCommand {
        static func invocation(
            shell: String,
            executable: String,
            workspace: URL,
            instructions: URL,
            attachments: [URL]
        ) throws -> String {
            let shellName = URL(fileURLWithPath: shell).lastPathComponent
            guard ["zsh", "bash", "sh", "ksh", "fish"].contains(shellName) else {
                throw LocalActionError(message: "The login shell must be bash, zsh, sh, ksh, or fish.")
            }
            let arguments = [executable, "--cwd", workspace.path, "--append-system-prompt", instructions.path]
                + attachments.map { "@" + $0.path }
            let command = arguments.map { argument in
                shellName == "fish" ? fishQuote(argument) : posixQuote(argument)
            }.joined(separator: " ")
            // exec leaves no PReek runner behind after interactive environment initialization.
            return [shell, "-i", "-l", "-c", "exec " + command].map(posixQuote).joined(separator: " ")
        }

        private static func posixQuote(_ value: String) -> String {
            "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        private static func fishQuote(_ value: String) -> String {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            return "'" + escaped + "'"
        }
    }
#endif
