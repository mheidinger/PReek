#if os(macOS)
    import SwiftUI

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case github
        case pullRequests = "pull-requests"
        case localActions = "local-actions"
        case about

        var id: Self {
            self
        }

        var title: LocalizedStringKey {
            switch self {
            case .general: "General"
            case .github: "GitHub"
            case .pullRequests: "Pull Requests"
            case .localActions: "Local Actions"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .github: "network"
            case .pullRequests: "arrow.triangle.pull"
            case .localActions: "terminal"
            case .about: "info.circle"
            }
        }

        var explanation: LocalizedStringKey {
            switch self {
            case .general: "Choose how PReek behaves in your menu bar."
            case .github: "Connect your GitHub account and share your configuration with another device."
            case .pullRequests: "Manage notification history, retention, and excluded contributors."
            case .localActions: "Configure local worktrees, editors, and saved agent actions."
            case .about: "App information and support."
            }
        }
    }
#endif
