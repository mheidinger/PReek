import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    
    var body: some View {
        Form {
            HelpTextField(type: .secureField, text: $configViewModel.token, label: "GitHub PAT") {
                Text("TODO: The Personal Access Token requires Notifications permissions")
                    .padding()
            }
            TextField("GitHub API endpoint", text: $configViewModel.apiBaseUrl)
            Toggle(isOn: $configViewModel.useSeparateGraphUrl) {
                Text("Use separate GraphQL endpoint")
            }
            TextField("GitHub GraphQL endpoint", text: $configViewModel.graphUrl)
                .disabled(!configViewModel.useSeparateGraphUrl)
        }
    }
}

#Preview {
    ConnectionSettingsView(configViewModel: ConfigViewModel())
        .padding()
}
