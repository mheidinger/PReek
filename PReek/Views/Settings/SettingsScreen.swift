import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
                    .background(.windowBackground)
            }
            .background(.windowBackground)
            .navigationTitle("Settings")
    }

    private var bottomBar: some View {
        HStack {
            #if os(macOS)
                Button("Quit App", action: { NSApplication.shared.terminate(nil) })
            #endif
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
            Section("Data Fetching and Cleanup") {
                Stepper(value: $configViewModel.onStartFetchWeeks, in: 0 ... 100) {
                    HStack {
                        Text("On start fetch PRs from notifications of last")
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
    SettingsView(configViewModel: ConfigViewModel())
}
