import Foundation

class ConfigViewModel: ObservableObject {
    @Published var currentUser: String? = nil

    @Published var useGitHubEnterprise: Bool = ConfigService.gitHubEnterpriseUrl != nil
    @Published var gitHubEnterpriseUrl: String = ConfigService.gitHubEnterpriseUrl ?? ""
    @Published var token: String = ConfigService.token ?? ""
    @Published var closeWindowOnLinkClick: Bool = ConfigService.closeWindowOnLinkClick
    @Published var onStartFetchWeeks: Int = ConfigService.onStartFetchWeeks
    @Published var deleteAfterWeeks: Int = ConfigService.deleteAfterWeeks
    @Published var deleteOnlyClosed: Bool = ConfigService.deleteOnlyClosed

    struct ExcludedUser: Identifiable {
        var id = UUID()
        var username: String
    }

    @Published var excludedUsers: [ExcludedUser] = ConfigService.excludedUsers.map { username in ExcludedUser(username: username) }

    func saveSettings() {
        if useGitHubEnterprise {
            ConfigService.gitHubEnterpriseUrl = gitHubEnterpriseUrl
        } else {
            ConfigService.gitHubEnterpriseUrl = nil
        }
        ConfigService.token = token
        ConfigService.closeWindowOnLinkClick = closeWindowOnLinkClick
        ConfigService.onStartFetchWeeks = onStartFetchWeeks
        ConfigService.deleteAfterWeeks = deleteAfterWeeks
        ConfigService.deleteOnlyClosed = deleteOnlyClosed
        ConfigService.excludedUsers = excludedUsers.map { excludedUser in excludedUser.username }
    }
}
