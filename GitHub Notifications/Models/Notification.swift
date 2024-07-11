//
//  Notification.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 27.05.24.
//

import Foundation

// Only contains relevant fields to request PR information for
struct Notification {
    var repo: String
    var prNumber: Int
}
