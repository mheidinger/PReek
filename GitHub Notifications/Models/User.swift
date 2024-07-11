//
//  User.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 10.07.24.
//

import Foundation

struct User {
    let login: String
    let url: URL?
    
    static func preview(login: String? = nil) -> User {
        User(
            login: login ?? "max-heidinger",
            url: URL(string: "https://example.com")!
        )
    }
}
