#if os(macOS)
    import Foundation

    /// Short, noninteractive commands. Cancellation waits for the child and both pipes
    /// rather than abandoning a Git transport that could keep mutating after a lock is released.
    enum LocalCommand {
        struct Result: Sendable {
            let status: Int32
            let output: String
            let error: String
        }

        private final class Capture: @unchecked Sendable {
            private let lock = NSLock()
            private var stdout = Data()
            private var stderr = Data()

            func setOutput(_ data: Data) {
                lock.lock()
                stdout = data
                lock.unlock()
            }

            func setError(_ data: Data) {
                lock.lock()
                stderr = data
                lock.unlock()
            }

            func result(status: Int32) -> Result {
                lock.lock()
                defer { lock.unlock() }
                return Result(
                    status: status,
                    output: String(decoding: stdout, as: UTF8.self),
                    error: String(decoding: stderr, as: UTF8.self)
                )
            }
        }

        static func run(
            _ executable: String,
            _ arguments: [String],
            directory: URL? = nil,
            environment: [String: String]? = nil
        ) async throws -> Result {
            try Task.checkCancellation()
            guard executable.hasPrefix("/"), !executable.contains("\0") else {
                throw LocalActionError(message: "The executable must be an absolute path.")
            }
            var values = ProcessInfo.processInfo.environment
            if let environment {
                values.merge(environment) { _, value in value }
            }
            // Do not let inherited Git overrides redirect a mapped clone's files.
            let redirects = [
                "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR",
                "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES",
                "GIT_CONFIG", "GIT_CONFIG_COUNT",
            ]
            for key in redirects {
                values.removeValue(forKey: key)
            }
            values["GIT_TERMINAL_PROMPT"] = "0"
            let paths = ["/opt/homebrew/bin", "/usr/local/bin"]
                + (values["PATH"] ?? "").split(separator: ":").map(String.init)
                + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
            values["PATH"] = paths.joined(separator: ":")
            let executableURL = URL(fileURLWithPath: executable)
            let commandEnvironment = values
            let result: Result = try await withCheckedThrowingContinuation { continuation in
                // Process launch and pipe reads never block the main actor. Each pipe
                // drains independently, including when the other fills its kernel buffer.
                DispatchQueue.global(qos: .utility).async {
                    let process = Process()
                    let output = Pipe()
                    let error = Pipe()
                    let capture = Capture()
                    let finished = DispatchGroup()
                    process.executableURL = executableURL
                    process.arguments = arguments
                    process.currentDirectoryURL = directory
                    process.environment = commandEnvironment
                    process.standardInput = FileHandle.nullDevice
                    process.standardOutput = output
                    process.standardError = error
                    finished.enter()
                    process.terminationHandler = { _ in
                        finished.leave()
                    }
                    do {
                        try process.run()
                    } catch let launchError {
                        process.terminationHandler = nil
                        try? output.fileHandleForWriting.close()
                        try? output.fileHandleForReading.close()
                        try? error.fileHandleForWriting.close()
                        try? error.fileHandleForReading.close()
                        continuation.resume(throwing: launchError)
                        return
                    }
                    try? output.fileHandleForWriting.close()
                    try? error.fileHandleForWriting.close()
                    finished.enter()
                    DispatchQueue.global(qos: .utility).async {
                        capture.setOutput(output.fileHandleForReading.readDataToEndOfFile())
                        try? output.fileHandleForReading.close()
                        finished.leave()
                    }
                    finished.enter()
                    DispatchQueue.global(qos: .utility).async {
                        capture.setError(error.fileHandleForReading.readDataToEndOfFile())
                        try? error.fileHandleForReading.close()
                        finished.leave()
                    }
                    finished.notify(queue: .global(qos: .utility)) {
                        // Retain Process until its termination handler and both drains finish.
                        withExtendedLifetime(process) {
                            continuation.resume(returning: capture.result(status: process.terminationStatus))
                        }
                    }
                }
            }
            try Task.checkCancellation()
            return result
        }

        static func checked(
            _ executable: String,
            _ arguments: [String],
            directory: URL? = nil,
            environment: [String: String]? = nil
        ) async throws -> String {
            let result = try await run(executable, arguments, directory: directory, environment: environment)
            guard result.status == 0 else {
                let details = (result.error.isEmpty ? result.output : result.error).trimmingCharacters(in: .whitespacesAndNewlines)
                let name = URL(fileURLWithPath: executable).lastPathComponent
                let suffix = details.isEmpty ? "." : ": \(details)"
                throw LocalActionError(message: "\(name) exited with status \(result.status)\(suffix)")
            }
            return result.output
        }
    }
#endif
