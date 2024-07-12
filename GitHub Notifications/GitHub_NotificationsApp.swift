//
//  GitHub_NotificationsApp.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 23.05.24.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct GitHub_NotificationsApp: App {
    @State var isMenuPresented: Bool = false
    
    var body: some Scene {
        MenuBarExtra("GitHub Notifications", image: "MenuBarIcon") {
            ContentView(closeWindow: { isMenuPresented = false })
                .frame(width: 600, height: 400)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 600, height: 400)
        .menuBarExtraAccess(isPresented: $isMenuPresented)
    }
}
