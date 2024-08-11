import Foundation

class ConfigService {
    @KeychainStorage("apiBaseUrl") static var apiBaseUrl: String = "https://api.github.com"
    @OptionalKeychainStorage("graphUrl") static var graphUrl: String? = nil
    @OptionalKeychainStorage("token") static var token: String? = nil
    
    @KeychainStorage("excludedUsers") private static var excludedUsersStr: String = ""
    static var excludedUsers: [String] {
        set { excludedUsersStr = newValue.joined(separator: "|") }
        get { return excludedUsersStr.split(separator: "|").map { subString in return String(subString)} }
    }
    
    @KeychainStorage("closeWindowOnLinkClick") private static var closeWindowOnLinkClickStr: String = "true"
    static var closeWindowOnLinkClick: Bool {
        set { closeWindowOnLinkClickStr = newValue ? "true" : "false" }
        get { return closeWindowOnLinkClickStr == "true" }
    }
}
