import LaunchAtLogin
import SwiftUI
#if os(iOS)
    import CodeScanner
#endif

func getAppVersion() -> String {
    if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        return appVersion
    }
    return "Unknown"
}

struct SettingsScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    @State private var showShareSheet = false
    @State private var showImportSheet = false

    #if os(macOS)
        @State private var selection: SettingsSection
        private let localActions: LocalActionsController?
        private let cleanup: LocalActionsCleanup?
        private let launchAtLogin: Binding<Bool>?

        init(
            configViewModel: ConfigViewModel,
            initialSection: SettingsSection = .general,
            localActions: LocalActionsController? = nil,
            cleanup: LocalActionsCleanup? = nil,
            launchAtLogin: Binding<Bool>? = nil
        ) {
            self.configViewModel = configViewModel
            _selection = State(initialValue: initialSection)
            self.localActions = localActions
            self.cleanup = cleanup
            self.launchAtLogin = launchAtLogin
        }

    #endif

    var body: some View {
        #if os(macOS)
            settingsNavigation
                .frame(minWidth: 780, minHeight: 560)
                .sheet(isPresented: $showShareSheet) {
                    VStack(spacing: 16) {
                        Text("Share Configuration")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("The QR code includes your GitHub token. Only share it with a device you trust.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ShareView(configViewModel: configViewModel, onDismiss: { showShareSheet = false })
                    }
                    .padding(20)
                    .frame(width: 440, height: 460)
                }
        #else
            Form {
                ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "GitHub Connection")
                pullRequestSettings
            }
            .formStyle(.grouped)
            .background(.windowBackground)
            .navigationTitle("Settings")
            .toolbar {
                Button(action: { showImportSheet = true }) {
                    Image(systemName: "qrcode.viewfinder")
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                NavigationStack {
                    ShareView(configViewModel: configViewModel, onDismiss: { showShareSheet = false })
                }
            }
            .importSheet(configViewModel: configViewModel, isPresented: $showImportSheet)
        #endif
    }

    #if os(macOS)
        private var settingsNavigation: some View {
            HStack(spacing: 0) {
                List(SettingsSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PReek")
                            .font(.headline)
                        Text("Version: \(getAppVersion())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .frame(width: 200)

                Divider()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selection.title)
                            .font(.largeTitle.bold())
                        Text(selection.explanation)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)

                    Form {
                        switch selection {
                        case .general:
                            generalSettings
                        case .github:
                            ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "GitHub Connection")
                            Section("Other Devices") {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Set up another device")
                                        Text("Transfer your connection and preferences. Includes your GitHub token.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Button("Show QR Code") {
                                        showShareSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    .fixedSize()
                                }
                                .padding(.vertical, 4)
                            }
                        case .pullRequests:
                            pullRequestSettings
                            ExcludedUsersTable(configViewModel: configViewModel)
                        case .localActions:
                            LocalActionsSettingsView(localActions: localActions ?? .shared, cleanup: cleanup ?? .shared)
                        case .about:
                            info
                        }
                    }
                    .formStyle(.grouped)
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .id(selection)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(.windowBackground)
            }
        }

        @ViewBuilder
        private var generalSettings: some View {
            Section("Startup") {
                if let launchAtLogin {
                    Toggle("Launch at login", isOn: launchAtLogin)
                } else {
                    LaunchAtLogin.Toggle()
                }
            }
            Section("Menu Bar") {
                Toggle("Close menu bar popover when opening a link", isOn: $configViewModel.closeWindowOnLinkClick)
                Text("Hold ⌘ while opening a link to do the opposite. This does not close the Settings window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        @ViewBuilder
        private var info: some View {
            Section {
                HStack(spacing: 16) {
                    Image(.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PReek")
                            .font(.title.bold())
                        Text("by Max Heidinger")
                            .foregroundStyle(.secondary)
                        Text("Version: \(getAppVersion())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Support") {
                HoverableLink("GitHub", destination: URL(string: "https://github.com/mheidinger/PReek")!)
                HoverableLink("FAQ", destination: URL(string: "https://github.com/mheidinger/PReek#faq")!)
                HoverableLink("Create Issue", destination: URL(string: "https://github.com/mheidinger/PReek/issues/new")!)
            }
        }
    #endif

    private var pullRequestSettings: some View {
        Section("Pull Requests") {
            Stepper(value: $configViewModel.onStartFetchWeeks, in: 0 ... 100) {
                HStack {
                    Text("Fetch PRs from notifications of last")
                    Spacer()
                    Text("\(configViewModel.onStartFetchWeeks) weeks")
                        .monospacedDigit()
                }
            }
            Stepper(value: $configViewModel.deleteAfterWeeks, in: 0 ... 100) {
                HStack {
                    Text("Remove PRs not updated since")
                    Spacer()
                    Text("\(configViewModel.deleteAfterWeeks) weeks")
                        .monospacedDigit()
                }
            }
            Toggle(isOn: $configViewModel.deleteOnlyClosed) {
                Text("Only remove closed PRs")
            }

            #if os(iOS)
                NavigationLink(value: Screen.excludedUsers) {
                    Text("Excluded Users")
                }
            #endif
        }
    }
}

#Preview {
    SettingsScreen(configViewModel: ConfigViewModel())
}
