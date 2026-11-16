#if os(iOS)
    import SwiftUI

    struct PReekIOSApp: App {
        @StateObject private var state: PReekAppState

        init() {
            let state = PReekAppState()
            _state = StateObject(wrappedValue: state)
            state.start()
        }

        var body: some Scene {
            WindowGroup {
                ContentView(
                    pullRequestsViewModel: state.pullRequestsViewModel,
                    configViewModel: state.configViewModel,
                    closeWindow: {}
                )
            }
        }
    }
#endif
