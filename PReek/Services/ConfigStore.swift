import Combine
import Foundation

/// Configuration values independent of preferences and credential storage.
struct ConfigValues {
    var token: String?
    var gitHubEnterpriseUrl: String?
    var onStartFetchWeeks: Int
    var deleteAfterWeeks: Int
    var deleteOnlyClosed: Bool
    var excludedUsers: [String]
    var closeWindowOnLinkClick: Bool

    init(
        token: String? = nil,
        gitHubEnterpriseUrl: String? = nil,
        onStartFetchWeeks: Int = 1,
        deleteAfterWeeks: Int = 1,
        deleteOnlyClosed: Bool = true,
        excludedUsers: [String] = [],
        closeWindowOnLinkClick: Bool = true
    ) {
        self.token = token
        self.gitHubEnterpriseUrl = gitHubEnterpriseUrl
        self.onStartFetchWeeks = onStartFetchWeeks
        self.deleteAfterWeeks = deleteAfterWeeks
        self.deleteOnlyClosed = deleteOnlyClosed
        self.excludedUsers = excludedUsers
        self.closeWindowOnLinkClick = closeWindowOnLinkClick
    }
}

protocol ConfigStore: AnyObject {
    var values: ConfigValues { get set }
    var onStartFetchWeeks: Int { get }
    var deleteAfterWeeks: Int { get }
    var deleteOnlyClosed: Bool { get }
    var excludedUsersSet: Set<String> { get }
    var excludedUsersDidChange: AnyPublisher<Void, Never> { get }
}

/// The live adapter preserves ConfigService's preference keys, Keychain storage, and notifications.
final class PersistentConfigStore: ConfigStore {
    var values: ConfigValues {
        get {
            ConfigValues(
                token: ConfigService.token,
                gitHubEnterpriseUrl: ConfigService.gitHubEnterpriseUrl,
                onStartFetchWeeks: ConfigService.onStartFetchWeeks,
                deleteAfterWeeks: ConfigService.deleteAfterWeeks,
                deleteOnlyClosed: ConfigService.deleteOnlyClosed,
                excludedUsers: ConfigService.excludedUsers,
                closeWindowOnLinkClick: ConfigService.closeWindowOnLinkClick
            )
        }
        set {
            ConfigService.token = newValue.token
            ConfigService.gitHubEnterpriseUrl = newValue.gitHubEnterpriseUrl
            ConfigService.onStartFetchWeeks = newValue.onStartFetchWeeks
            ConfigService.deleteAfterWeeks = newValue.deleteAfterWeeks
            ConfigService.deleteOnlyClosed = newValue.deleteOnlyClosed
            ConfigService.excludedUsers = newValue.excludedUsers
            ConfigService.closeWindowOnLinkClick = newValue.closeWindowOnLinkClick
        }
    }

    /// Refresh and retention only need preferences, not a full credential snapshot.
    var onStartFetchWeeks: Int {
        ConfigService.onStartFetchWeeks
    }

    var deleteAfterWeeks: Int {
        ConfigService.deleteAfterWeeks
    }

    var deleteOnlyClosed: Bool {
        ConfigService.deleteOnlyClosed
    }

    var excludedUsersSet: Set<String> {
        ConfigService.excludedUsersSet
    }

    var excludedUsersDidChange: AnyPublisher<Void, Never> {
        ConfigService.excludedUsersDidChange.eraseToAnyPublisher()
    }
}

/// An owning, mutable store that never accesses UserDefaults, Keychain, or ConfigService.
final class MemoryConfigStore: ConfigStore {
    private let excludedUsersChanges = PassthroughSubject<Void, Never>()
    private(set) var excludedUsersSet: Set<String>

    var values: ConfigValues {
        didSet {
            if values.excludedUsers != oldValue.excludedUsers {
                excludedUsersSet = Set(values.excludedUsers)
            }
            excludedUsersChanges.send()
        }
    }

    var onStartFetchWeeks: Int {
        values.onStartFetchWeeks
    }

    var deleteAfterWeeks: Int {
        values.deleteAfterWeeks
    }

    var deleteOnlyClosed: Bool {
        values.deleteOnlyClosed
    }

    var excludedUsersDidChange: AnyPublisher<Void, Never> {
        excludedUsersChanges.eraseToAnyPublisher()
    }

    init(values: ConfigValues = ConfigValues()) {
        self.values = values
        excludedUsersSet = Set(values.excludedUsers)
    }
}
