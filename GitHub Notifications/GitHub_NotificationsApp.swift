//
//  GitHub_NotificationsApp.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 23.05.24.
//

import SwiftUI

@main
struct GitHub_NotificationsApp: App {
    var body: some Scene {
        MenuBarExtra("GitHub Notifications", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 600, height: 400)
    }
}
