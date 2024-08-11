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
    
    @KeychainStorage("onStartFetchWeeks") static var onStartFetchWeeksStr: String = "1"
    static var onStartFetchWeeks: Int {
        set { onStartFetchWeeksStr = String(newValue) }
        get {
            guard let number = Int(onStartFetchWeeksStr) else {
                return 1
            }
            return number
        }
    }
    
    @KeychainStorage("deleteAfterWeeks") static var deleteAfterWeeksStr: String = "1"
    static var deleteAfterWeeks: Int {
        set { deleteAfterWeeksStr = String(newValue) }
        get {
            guard let number = Int(deleteAfterWeeksStr) else {
                return 1
            }
            return number
        }
    }
    
    @KeychainStorage("deleteOnlyClosed") private static var deleteOnlyClosedStr: String = "true"
    static var deleteOnlyClosed: Bool {
        set { deleteOnlyClosedStr = newValue ? "true" : "false" }
        get { return deleteOnlyClosedStr == "true" }
    }
}
