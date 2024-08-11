import SwiftUI
import MenuBarExtraAccess

@main
struct PReekApp: App {
    @State var isMenuPresented: Bool = false
    
    var body: some Scene {
        MenuBarExtra("PReek", image: "MenuBarIcon") {
            ContentView(closeWindow: { isMenuPresented = false })
                .frame(width: 600, height: 400)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 600, height: 400)
        .menuBarExtraAccess(isPresented: $isMenuPresented)
    }
}
