import Combine
import Foundation
import OSLog

class ConfigViewModel: ObservableObject {
    private let logger = Logger()
    private var cancellables = Set<AnyCancellable>()
    private let saveUpdateTrigger = PassthroughSubject<Void, Never>()

    struct ExcludedUser: Identifiable {
        var id = UUID()
        var username: String
    }

    @Published var currentUser: String? = nil {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var useGitHubEnterprise: Bool = ConfigService.gitHubEnterpriseUrl != nil {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var gitHubEnterpriseUrl: String = ConfigService.gitHubEnterpriseUrl ?? "" {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var token: String = ConfigService.token ?? "" {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var onStartFetchWeeks: Int = ConfigService.onStartFetchWeeks {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var deleteAfterWeeks: Int = ConfigService.deleteAfterWeeks {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var deleteOnlyClosed: Bool = ConfigService.deleteOnlyClosed {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var excludedUsers: [ExcludedUser] = ConfigService.excludedUsers.map { username in ExcludedUser(username: username) } {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    @Published var closeWindowOnLinkClick: Bool = ConfigService.closeWindowOnLinkClick {
        didSet {
            saveUpdateTrigger.send()
        }
    }

    init() {
        setupSaveUpdate()
    }

    func addExcludedUser(username: String) {
        excludedUsers.append(ConfigViewModel.ExcludedUser(username: username))
        saveUpdateTrigger.send()
    }

    func removeExcludedUser(_ excludedUser: ExcludedUser) {
        excludedUsers.removeAll { $0.id == excludedUser.id }
        saveUpdateTrigger.send()
    }

    private func setupSaveUpdate() {
        saveUpdateTrigger
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }

    func saveSettings() {
        logger.info("Saving settings...")
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
