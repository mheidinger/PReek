import SwiftUI

class ConfigService {
    @OptionalKeychainStorage("gitHubEnterpriseUrl") static var gitHubEnterpriseUrl: String? = nil
    @OptionalKeychainStorage("token") static var token: String? = nil

    @AppStorage("onStartFetchWeeks") static var onStartFetchWeeks: Int = 1
    @AppStorage("deleteAfterWeeks") static var deleteAfterWeeks: Int = 1
    @AppStorage("deleteOnlyClosed") static var deleteOnlyClosed: Bool = true

    @AppStorage("excludedUsers") private static var excludedUsersStr: String = ""

    // Performance optimization: Cache excluded users as Set for O(1) lookups
    private static var excludedUsersCache: Set<String>?
    private static var lastExcludedUsersStr: String = ""

    static var excludedUsersSet: Set<String> {
        if excludedUsersStr != lastExcludedUsersStr || excludedUsersCache == nil {
            excludedUsersCache = Set(excludedUsersStr.split(separator: "|").map { String($0) })
            lastExcludedUsersStr = excludedUsersStr
        }
        return excludedUsersCache!
    }

    static var excludedUsers: [String] {
        set {
            excludedUsersStr = newValue.joined(separator: "|")
            // Invalidate cache when setting new value
            excludedUsersCache = nil
        }
        get {
            return Array(excludedUsersSet) // Use the cached Set, converted to Array
        }
    }

    @AppStorage("closeWindowOnLinkClick") static var closeWindowOnLinkClick: Bool = true
}
