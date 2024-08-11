import SwiftUI

class ConfigService {
    @KeychainStorage("apiBaseUrl") static var apiBaseUrl: String = "https://api.github.com"
    @OptionalKeychainStorage("graphUrl") static var graphUrl: String? = nil
    @OptionalKeychainStorage("token") static var token: String? = nil
    
    @AppStorage("closeWindowOnLinkClick") static var closeWindowOnLinkClick: Bool = true
    @AppStorage("onStartFetchWeeks") static var onStartFetchWeeks: Int = 1
    @AppStorage("deleteAfterWeeks") static var deleteAfterWeeks: Int = 1
    @AppStorage("deleteOnlyClosed") static var deleteOnlyClosed: Bool = true
    @AppStorage("hideClosed") static var hideClosed: Bool = true
    @AppStorage("hideRead") static var hideRead: Bool = true
    
    @AppStorage("excludedUsers") private static var excludedUsersStr: String = ""
    static var excludedUsers: [String] {
        set { excludedUsersStr = newValue.joined(separator: "|") }
        get { return excludedUsersStr.split(separator: "|").map { subString in return String(subString)} }
    }
    
}
