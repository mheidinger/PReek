import LaunchAtLogin
import OSLog
import SwiftUI
#if os(iOS)
    import CodeScanner
#endif

struct SettingsScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    @State private var showShareSheet: Bool = false
    @State private var showImportSheet: Bool = false

    var body: some View {
        content
            .background(.windowBackground)
            .navigationTitle("Settings")
        #if os(iOS)
            // Not shown on macOS - https://stackoverflow.com/questions/77647716/macos-swiftui-using-navigationstack-toolbar-button-not-showing-in-menubarextra-a
            .toolbar {
                Button(action: { showImportSheet = true }) {
                    Image(systemName: "qrcode.viewfinder")
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            // Not possible to use on macOS due to a bug - https://stackoverflow.com/questions/78835562/opening-a-sheet-inside-a-menubarextra
            .sheet(isPresented: $showShareSheet) {
                NavigationStack {
                    ShareView(configViewModel: configViewModel, onDismiss: { showShareSheet = false })
                }
            }
            .importSheet(configViewModel: configViewModel, isPresented: $showImportSheet)
        #endif
        #if os(macOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Button("Quit App", action: { NSApplication.shared.terminate(nil) })
                NavigationLink(value: Screen.share) {
                    Text("Share")
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.windowBackground)
        }
        #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                #if os(macOS)
                    info
                #endif

                ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "GitHub Connection")

                pullRequestSettings

                #if os(macOS)
                    Section("Additional Settings") {
                        LaunchAtLogin.Toggle()
                        Toggle(isOn: $configViewModel.closeWindowOnLinkClick) {
                            Text("Close window when opening a link, press CMD on click to get opposite behaviour")
                        }
                    }
                #endif
            }
            .formStyle(.grouped)
        }
    }

    private var info: some View {
        Section {
            HStack(spacing: 15) {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                VStack(alignment: .leading) {
                    Text("PReek")
                        .font(.title)
                    Text("by Max Heidinger")
                        .font(.title3)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    HoverableLink("GitHub", destination: URL(string: "https://github.com/mheidinger/PReek")!)
                    HoverableLink("FAQ", destination: URL(string: "https://github.com/mheidinger/PReek#faq")!)
                    HoverableLink("Create Issue", destination: URL(string: "https://github.com/mheidinger/PReek/issues/new")!)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var pullRequestSettings: some View {
        Section("Pull Requests") {
            Stepper(value: $configViewModel.onStartFetchWeeks, in: 0 ... 100) {
                HStack {
                    Text("Fetch PRs from notifications of last")
                    Spacer()
                    Text("\(configViewModel.onStartFetchWeeks) weeks")
                }
            }
            Stepper(value: $configViewModel.deleteAfterWeeks, in: 0 ... 100) {
                HStack {
                    Text("Remove PRs not updated since")
                    Spacer()
                    Text("\(configViewModel.deleteAfterWeeks) weeks")
                }
            }
            Toggle(isOn: $configViewModel.deleteOnlyClosed) {
                Text("Only remove closed PRs")
            }

            #if os(macOS)
                ExcludedUsersTable(configViewModel: configViewModel)
            #else
                NavigationLink(value: Screen.excludedUsers) {
                    Text("Excluded Users")
                }
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        SettingsScreen(configViewModel: ConfigViewModel())
    }
}
