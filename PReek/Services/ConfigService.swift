import SwiftUI

class ConfigService {
    @OptionalKeychainStorage("gitHubEnterpriseUrl") static var gitHubEnterpriseUrl: String? = nil
    @OptionalKeychainStorage("token") static var token: String? = nil

    @AppStorage("closeWindowOnLinkClick") static var closeWindowOnLinkClick: Bool = true
    @AppStorage("onStartFetchWeeks") static var onStartFetchWeeks: Int = 1
    @AppStorage("deleteAfterWeeks") static var deleteAfterWeeks: Int = 1
    @AppStorage("deleteOnlyClosed") static var deleteOnlyClosed: Bool = true

    @AppStorage("excludedUsers") private static var excludedUsersStr: String = ""
    static var excludedUsers: [String] {
        set { excludedUsersStr = newValue.joined(separator: "|") }
        get { return excludedUsersStr.split(separator: "|").map { subString in String(subString) } }
    }
}
