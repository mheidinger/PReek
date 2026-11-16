import Foundation

/// Render requests must be dispatched before SwiftUI constructs the app and its live services.
@main
enum PReekEntryPoint {
    @MainActor
    static func main() {
        let launchArguments = Array(CommandLine.arguments.dropFirst())
        if launchArguments.contains(where: { $0.hasPrefix("--debug-offline") }) {
            #if DEBUG
                if launchArguments == ["--debug-offline", "--help"] {
                    print(DebugOfflineSession.Options.usage)
                    exit(EXIT_SUCCESS)
                }
                do {
                    let options = try DebugOfflineSession.Options.parse(launchArguments)
                    try DebugOfflineApp.launch(options: options)
                    exit(EXIT_SUCCESS)
                } catch {
                    FileHandle.standardError.write(Data("Offline debug launch failed: \(error.localizedDescription)\n".utf8))
                    exit(EXIT_FAILURE)
                }
            #else
                FileHandle.standardError.write(Data("Offline debug mode is available only in Debug builds.\n".utf8))
                exit(EXIT_FAILURE)
            #endif
        }
        #if os(macOS)
            if launchArguments.contains(where: { $0.hasPrefix("--render-ui") }) {
                #if DEBUG
                    do {
                        try UIRenderer.run(arguments: launchArguments)
                        exit(EXIT_SUCCESS)
                    } catch {
                        FileHandle.standardError.write(Data("UI rendering failed: \(error.localizedDescription)\n".utf8))
                        exit(EXIT_FAILURE)
                    }
                #else
                    FileHandle.standardError.write(Data("UI rendering is available only in Debug builds.\n".utf8))
                    exit(EXIT_FAILURE)
                #endif
            }
        #else
            if launchArguments.contains(where: { $0.hasPrefix("--render-ui") }) {
                FileHandle.standardError.write(Data("Off-screen rendering is available only on macOS.\n".utf8))
                exit(EXIT_FAILURE)
            }
        #endif
        #if os(macOS)
            PReekMacOSApp.main()
        #elseif os(iOS)
            PReekIOSApp.main()
        #endif
    }
}
