#if os(macOS)
    import AppKit
    import Foundation

    /// Installed supported applications, opened natively rather than through their CLI wrappers.
    struct LocalEditor: Identifiable {
        let id: String
        let name: String
        let applicationURL: URL
        let icon: NSImage

        @MainActor
        static func discover() -> [LocalEditor] {
            let workspace = NSWorkspace.shared
            return presets.compactMap { preset in
                guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: preset.id) else {
                    return nil
                }
                return LocalEditor(
                    id: preset.id,
                    name: preset.name,
                    applicationURL: applicationURL,
                    icon: workspace.icon(forFile: applicationURL.path)
                )
            }
        }

        /// An explicit choice stays unavailable if uninstalled; never silently open a different app.
        static func preferredID(savedID: String?, installedIDs: [String]) -> String? {
            if let savedID = savedID?.trimmingCharacters(in: .whitespacesAndNewlines), !savedID.isEmpty {
                return savedID
            }
            return installedIDs.contains("dev.zed.Zed") ? "dev.zed.Zed" : installedIDs.first
        }

        private static let presets: [(id: String, name: String)] = [
            ("dev.zed.Zed", "Zed"),
            ("com.microsoft.VSCode", "VS Code"),
            ("com.microsoft.VSCodeInsiders", "VS Code Insiders"),
            ("com.todesktop.230313mzl4w4u92", "Cursor"),
            ("com.vscodium", "VSCodium"),
        ]
    }
#endif
