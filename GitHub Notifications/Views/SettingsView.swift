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
            .padding()
            
            ScrollView {
                content
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            
            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit App")
                }
                Spacer()
                Button("Save Settings", action: configViewModel.saveSettings)
            }
            .padding()
        }
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
        }
    }
}

#Preview {
    SettingsView(settingsOpen: .constant(true), configViewModel: ConfigViewModel())
}
