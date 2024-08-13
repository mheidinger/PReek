import SwiftUI

struct SettingsView: View {
    @Binding var settingsOpen: Bool
    @ObservedObject var configViewModel: ConfigViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("Settings")
                    .font(.title)
                    .bold()
                Spacer()
                Button(action: { settingsOpen = false }) {
                    Image(systemName: "xmark.circle")
                        .font(.title)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                content
                    .padding(.horizontal)
            }
            .padding(.trailing, 10)
            
            HStack {
                Button("Quit App", action: { NSApplication.shared.terminate(nil) })
                Spacer()
                Button("Save Settings", action: configViewModel.saveSettings)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(.windowBackground)
    }
    
    func addExcludedUserEntry() {
        configViewModel.excludedUsers.append(ConfigViewModel.ExcludedUser(username: ""))
    }
    
    func removeExcludedUserEntry(id: UUID) {
        configViewModel.excludedUsers = configViewModel.excludedUsers.filter({ excludedUser in
            return excludedUser.id != id
        })
    }
    
    @State private var count: Int = 0
    
    @ViewBuilder
    var content: some View {
        VStack(alignment: .leading) {
            Section(header: Text("GitHub Connection:").bold()) {
                ConnectionSettingsView(configViewModel: configViewModel)
            }
            Divider()
            Section(header: Text("Pull Requests").bold()) {
                HStack {
                    Text("On start fetch PRs from notifications of last")
                    Spacer()
                    Stepper("\(configViewModel.onStartFetchWeeks) weeks",
                            value: $configViewModel.onStartFetchWeeks,
                            in: 0...100
                    )
                }
                HStack {
                    Text("Remove PRs not updated since")
                    Spacer()
                    Stepper("\(configViewModel.deleteAfterWeeks) weeks",
                            value: $configViewModel.deleteAfterWeeks,
                            in: 1...100
                    )
                }
                Toggle(isOn: $configViewModel.deleteOnlyClosed) {
                    Text("Only remove closed PRs")
                }
                
                Text("Ignore PRs with only the following contributors:")
                VStack {
                    ForEach($configViewModel.excludedUsers.enumerated().map({$0}), id: \.element.id) { index, $item in
                        HStack {
                            TextField("Excluded User #\(index + 1)", text: $item.username)
                                .labelsHidden()
                            Button("Remove", action: {removeExcludedUserEntry(id: $item.id)})
                        }
                    }
                }
                Button("Add Entry", action: addExcludedUserEntry)
                    .padding(.top, 5)
            }
            Divider()
            Section(header: Text("Additional Settings").bold()) {
                Toggle(isOn: $configViewModel.closeWindowOnLinkClick) {
                    Text("Close window when opening a link, press CMD on click to get opposite behaviour")
                }
            }
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    SettingsView(settingsOpen: .constant(true), configViewModel: ConfigViewModel())
}
