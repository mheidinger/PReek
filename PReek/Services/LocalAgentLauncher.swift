#if os(macOS)
    import AppKit
    import Darwin
    import Foundation

    /// The agent-only handoff. Shared workspace preparation belongs to LocalActionsController.
    @MainActor
    enum LocalAgentLauncher {
        static func launch(
            _ action: LocalAgentAction,
            pullRequestURL: URL,
            workspace: LocalWorkspaceService.PreparedWorkspace,
            executable: String
        ) async throws {
            let context = try await LocalAgentContext.prepare(action: action, pullRequestURL: pullRequestURL, workspace: workspace)
            do {
                try Task.checkCancellation()
                let command = try LocalAgentCommand.invocation(
                    shell: userShell,
                    executable: executable,
                    workspace: workspace.url,
                    instructions: context.instructions,
                    attachments: context.attachments
                )
                try openGhostty(command: command, directory: workspace.url)
            } catch {
                try? FileManager.default.removeItem(at: context.directory)
                throw error
            }
        }

        private static var userShell: String {
            guard let shell = getpwuid(getuid())?.pointee.pw_shell else { return "/bin/zsh" }
            let path = String(cString: shell)
            return path.isEmpty ? "/bin/zsh" : path
        }

        private static func openGhostty(command: String, directory: URL) throws {
            let environment = [
                "HOME=\(FileManager.default.homeDirectoryForCurrentUser.path)",
                "SHELL=\(userShell)",
            ].map(appleScriptString).joined(separator: ", ")
            let source = """
            tell application id "com.mitchellh.ghostty"
                set cfg to new surface configuration
                set command of cfg to \(appleScriptString(command))
                set wait after command of cfg to true
                set environment variables of cfg to {\(environment)}
                set initial working directory of cfg to \(appleScriptString(directory.path))
                new window with configuration cfg
                activate
            end tell
            """
            guard let script = NSAppleScript(source: source) else {
                throw LocalActionError(message: "Could not prepare the Ghostty command.")
            }
            var details: NSDictionary?
            script.executeAndReturnError(&details)
            if let details {
                let message = details[NSAppleScript.errorMessage] as? String ?? details.description
                throw LocalActionError(message: "\(message)\n\nInstall Ghostty 1.3 or newer with AppleScript enabled, and allow PReek to control Ghostty in System Settings → Privacy & Security → Automation.")
            }
        }

        private static func appleScriptString(_ value: String) -> String {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"" + escaped + "\""
        }
    }
#endif
