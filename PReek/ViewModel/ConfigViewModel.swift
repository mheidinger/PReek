import Foundation

class ConfigViewModel: ObservableObject {
    struct ExcludedUser: Identifiable {
        var id = UUID()
        var username: String
    }

    @Published var currentUser: String? = nil

    @Published var useGitHubEnterprise: Bool = ConfigService.gitHubEnterpriseUrl != nil
    @Published var gitHubEnterpriseUrl: String = ConfigService.gitHubEnterpriseUrl ?? ""
    @Published var token: String = ConfigService.token ?? ""

    @Published var onStartFetchWeeks: Int = ConfigService.onStartFetchWeeks
    @Published var deleteAfterWeeks: Int = ConfigService.deleteAfterWeeks
    @Published var deleteOnlyClosed: Bool = ConfigService.deleteOnlyClosed
    @Published var excludedUsers: [ExcludedUser] = ConfigService.excludedUsers.map { username in ExcludedUser(username: username) }

    @Published var closeWindowOnLinkClick: Bool = ConfigService.closeWindowOnLinkClick

    func addExcludedUser(username: String) {
        excludedUsers.append(ConfigViewModel.ExcludedUser(username: username))
    }

    func removeExcludedUser(_ excludedUser: ExcludedUser) {
        excludedUsers.removeAll { $0.id == excludedUser.id }
    }

    func saveSettings() {
        ConfigService.token = token
        if useGitHubEnterprise {
            ConfigService.gitHubEnterpriseUrl = gitHubEnterpriseUrl
        } else {
            ConfigService.gitHubEnterpriseUrl = nil
        }

        ConfigService.onStartFetchWeeks = onStartFetchWeeks
        ConfigService.deleteAfterWeeks = deleteAfterWeeks
        ConfigService.deleteOnlyClosed = deleteOnlyClosed
        ConfigService.excludedUsers = excludedUsers.map { excludedUser in excludedUser.username }

        ConfigService.closeWindowOnLinkClick = closeWindowOnLinkClick
    }
}
