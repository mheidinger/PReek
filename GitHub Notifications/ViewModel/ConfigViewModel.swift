//
//  ConfigViewModel.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 30.05.24.
//

import Foundation

class ConfigViewModel: ObservableObject {
    @Published var currentUser: String? = nil
    
    @Published var apiBaseUrl: String = ConfigService.apiBaseUrl
    @Published var useSeparateGraphUrl: Bool = ConfigService.graphUrl != nil
    @Published var graphUrl: String = ConfigService.graphUrl ?? ""
    @Published var token: String = ConfigService.token ?? ""
    
    struct ExcludedUser: Identifiable {
        var id = UUID()
        var username: String
    }
    
    @Published var excludedUsers: [ExcludedUser] = ConfigService.excludedUsers.map { username in return ExcludedUser(username: username)}
    
    @Published var closeWindowOnLinkClick: Bool = ConfigService.closeWindowOnLinkClick
    
    func saveSettings() {
        ConfigService.apiBaseUrl = apiBaseUrl
        if useSeparateGraphUrl {
            ConfigService.graphUrl = graphUrl
        } else {
            ConfigService.graphUrl = nil
        }
        ConfigService.token = token
        ConfigService.excludedUsers = excludedUsers.map { excludedUser in return excludedUser.username }
        ConfigService.closeWindowOnLinkClick = closeWindowOnLinkClick
    }
}
