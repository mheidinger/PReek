import Combine
import Foundation
import OSLog

class ConfigViewModel: ObservableObject {
    private let logger = Logger()
    private let decoder = JSONDecoder()
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

    @Published var excludedUsers: [ExcludedUser] = ConfigService.excludedUsers.map { ExcludedUser(username: $0) } {
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

    func removeExcludedUserByIndexSet(_ indexSet: IndexSet) {
        excludedUsers.remove(atOffsets: indexSet)
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
        ConfigService.excludedUsers = excludedUsers.map { $0.username }

        ConfigService.closeWindowOnLinkClick = closeWindowOnLinkClick
    }

    func getShareData() -> ShareConfig? {
        if token.isEmpty {
            return nil
        }

        return ShareConfig.v1(ShareConfigDataV1(
            token: token,
            gitHubEnterpriseUrl: useGitHubEnterprise ? gitHubEnterpriseUrl : nil,
            onStartFetchWeeks: onStartFetchWeeks,
            deleteAfterWeeks: deleteAfterWeeks,
            deleteOnlyClosed: deleteOnlyClosed,
            excludedUsers: excludedUsers.map { $0.username }
        ))
    }

    func importShareData(_ shareData: Data) throws {
        do {
            let parsedData = try decoder.decode(ShareConfig.self, from: shareData)

            switch parsedData {
            case let .v1(parsedData):
                token = parsedData.token
                if let parsedGitHubEnterpriseUrl = parsedData.gitHubEnterpriseUrl {
                    useGitHubEnterprise = true
                    gitHubEnterpriseUrl = parsedGitHubEnterpriseUrl
                } else {
                    useGitHubEnterprise = false
                }
                onStartFetchWeeks = parsedData.onStartFetchWeeks
                deleteAfterWeeks = parsedData.deleteAfterWeeks
                deleteOnlyClosed = parsedData.deleteOnlyClosed
                excludedUsers = parsedData.excludedUsers.map { ExcludedUser(username: $0) }
            }
        } catch {
            logger.error("Failed to decode imported share data: \(error)")
            throw AppError.failedToImportShareData
        }
    }
}
