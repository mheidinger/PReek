//
//  SettingsView.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 26.05.24.
//

import SwiftUI

struct SettingsView: View {
    @Binding var settingsOpen: Bool
    @ObservedObject var configViewModel: ConfigViewModel
    
    var body: some View {
        VStack {
            HStack {
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
    
    @ViewBuilder
    var content: some View {
        Form {
            Section("GitHub Connection:") {
                TextField("GitHub API endpoint", text: $configViewModel.apiBaseUrl)
                Toggle(isOn: $configViewModel.useSeparateGraphUrl) {
                    Text("Use separate GraphQL endpoint")
                }
                TextField("GitHub GraphQL endpoint", text: $configViewModel.graphUrl)
                    .disabled(!configViewModel.useSeparateGraphUrl)
                SecureField("GitHub PAT", text: $configViewModel.token)
            }
            Divider()
            Section("Ignore PRs with only the following contributors:") {
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
            }
            Divider()
            Section("Additional Settings") {
                Toggle(isOn: $configViewModel.closeWindowOnLinkClick) {
                    Text("Close window when opening a link, press CMD on click to get opposite behaviour")
                }
            }
        }
    }
}

#Preview {
    SettingsView(settingsOpen: .constant(true), configViewModel: ConfigViewModel())
}
