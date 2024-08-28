import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var body: some View {
        Form {
            HelpTextField(type: .secureField, text: $configViewModel.token, label: "GitHub PAT") {
                VStack(alignment: .leading) {
                    Text("The Personal Access Token (PAT) should be of type 'classic' and requires the 'notifications' scope. For access to private repositories, additionally the 'repo' scope is required. Notifications are used to get the Pull Requests that are shown yo you. See the GitHub documentation on how to generate a PAT.")
                    Link("GitHub Documentation", destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic")!)
                }
                .padding()
                .frame(width: 300)
            }
            Toggle(isOn: $configViewModel.useGitHubEnterprise) {
                Text("Use GitHub Enterprise")
                #if os(macOS)
                    // Make this have the widest label to avoid a layout shift when URL field is shown
                    .frame(width: 170, alignment: .trailing)
                #endif
            }
            .toggleStyle(.switch)
            if configViewModel.useGitHubEnterprise {
                HelpTextField(type: .textField, text: $configViewModel.gitHubEnterpriseUrl, label: "GitHub Enterprise URL") {
                    VStack(alignment: .leading) {
                        Text("Provide the base URL without any suffix.\nFor example:")
                        Text(verbatim: "https://github.acme.org")
                            .monospaced()
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    ConnectionSettingsView(configViewModel: ConfigViewModel())
        .padding()
}
