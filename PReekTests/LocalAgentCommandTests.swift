#if os(macOS)
    import Foundation
    import Testing

    struct LocalAgentCommandTests {
        private static var fishExecutable: String? {
            let paths = ["/opt/homebrew/bin", "/usr/local/bin"]
                + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
            return paths.map { $0 + "/fish" }.first { FileManager.default.isExecutableFile(atPath: $0) }
        }

        @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/ksh"])
        func preservesArgumentsThroughBothShellLayers(_ shell: String) async throws {
            try await roundTrip(shell: shell)
        }

        @Test(.enabled(if: LocalAgentCommandTests.fishExecutable != nil, "fish is not installed"))
        func preservesFishBackslashesAndQuotes() async throws {
            try await roundTrip(shell: #require(Self.fishExecutable))
        }

        private func roundTrip(shell: String) async throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let unusual = "quote' pair\\\\ single\\ $(touch NEVER_EXECUTE)\nspace 雪"
            let executable = directory.appendingPathComponent("agent-" + unusual)
            try Data("#!/bin/sh\nprintf '%s\\0' \"$@\"\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
            let workspace = directory.appendingPathComponent(unusual)
            let instructions = workspace.appendingPathComponent("instructions.txt")
            let attachments = [workspace.appendingPathComponent("prompt.txt"), workspace.appendingPathComponent("context.json")]
            let command = try LocalAgentCommand.invocation(
                shell: shell, executable: executable.path, workspace: workspace,
                instructions: instructions, attachments: attachments
            )
            let result = try await LocalCommand.run("/bin/sh", ["-c", command], directory: directory, environment: [
                "HOME": directory.path, "ZDOTDIR": directory.path, "XDG_CONFIG_HOME": directory.path,
                "ENV": "/dev/null", "BASH_ENV": "/dev/null", "TERM": "dumb",
            ])
            #expect(result.status == 0, "\(result.error)")
            let arguments = result.output.split(separator: "\0", omittingEmptySubsequences: false).dropLast().map(String.init)
            #expect(arguments == ["--cwd", workspace.path, "--append-system-prompt", instructions.path] + attachments.map { "@" + $0.path })
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("NEVER_EXECUTE").path))
        }
    }
#endif
