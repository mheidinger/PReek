import SwiftUI
import MenuBarExtraAccess

@main
struct PReekApp: App {
    @State var isMenuPresented: Bool = false
    @State var showUnreadIcon: Bool = false
    
    var body: some Scene {
        MenuBarExtra("PReek", image: showUnreadIcon ? "MenuBarIconUnread" : "MenuBarIcon") {
            ContentView(closeWindow: { isMenuPresented = false }, setUnreadIcon: { showUnread in showUnreadIcon = showUnread })
                .frame(width: 600, height: 400)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 600, height: 400)
        .menuBarExtraAccess(isPresented: $isMenuPresented)
    }
}
