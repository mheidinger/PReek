import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    
    var body: some View {
        Form {
            HelpTextField(type: .secureField, text: $configViewModel.token, label: "GitHub PAT") {
                VStack(alignment: .leading) {
                    Text("The Personal Access Token (PAT) requires 'notifications' permissions. See the documentation on how to generate a PAT.")
                    Link("GitHub Documentation", destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic")!)
                }
                .frame(width: 300)
                .padding(.vertical)
            }
            Toggle(isOn: $configViewModel.useGitHubEnterprise) {
                // Make this have the widest label to avoid a layout shift when URL field is shown
                Text("Use GitHub Enterprise")
                    .frame(width: 170, alignment: .trailing)
            }
            .toggleStyle(.switch)
            if (configViewModel.useGitHubEnterprise) {
                HelpTextField(type: .textField, text: $configViewModel.gitHubEnterpriseUrl, label: "GitHub Enterprise URL") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Provide the base URL without any suffix. For example:")
                        Text(verbatim: "https://github.acme.org")
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(width: 300)
                    .padding(.vertical)
                }
            }
        }
    }
}

#Preview {
    ConnectionSettingsView(configViewModel: ConfigViewModel())
        .padding()
}
