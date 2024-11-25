import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    var headerLabel: LocalizedStringKey
    
    @State private var showPopover = false
    
    var body: some View {
        Section {
            HelpTextField(type: .revealSecureField, text: $configViewModel.token, label: "GitHub PAT") {
                VStack(alignment: .leading) {
                    Text("The Personal Access Token (PAT) should be of type 'classic' and requires the 'notifications' scope. For access to private repositories, additionally the 'repo' scope is required. Notifications are used to get the Pull Requests that are shown yo you. See the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) on how to generate a PAT.")
                }
                .padding()
                .frame(width: 300)
            }
            Toggle(isOn: $configViewModel.useGitHubEnterprise) {
                Text("Use GitHub Enterprise")
            }
            .toggleStyle(.switch)
            if configViewModel.useGitHubEnterprise {
                HelpTextField(type: .textField, text: $configViewModel.gitHubEnterpriseUrl, label: "GitHub Enterprise URL") {
                    VStack(alignment: .leading) {
                        Text("Provide the base URL without any suffix. For example:")
                        Text(verbatim: "https://github.acme.org")
                            .monospaced()
                    }
                    .padding()
                }
            }
        } header: {
            HStack {
                Text(headerLabel)
                Button(action: { showPopover.toggle() }) {
                    Image(systemName: "questionmark.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showPopover, content: {
            VStack(alignment: .leading) {
                HStack {
                    Text("GitHub Connection")
                        .font(.title)
                    Spacer()
                    Button(action: { showPopover.toggle() }) {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                    }
                }
                .padding(.bottom)
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("GitHub PAT")
                        .font(.title3)
                    Text("The Personal Access Token (PAT) should be of type 'classic' and requires the 'notifications' scope. For access to private repositories, additionally the 'repo' scope is required. Notifications are used to get the Pull Requests that are shown yo you. See the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) on how to generate a PAT.")
                        .font(.footnote)
                        .padding(.bottom)
                    
                    Text("GitHub Enterprise URL")
                        .font(.title3)
                    Group {
                        Text("Provide the base URL without any suffix. For example:")
                        Text(verbatim: "https://github.acme.org")
                            .monospaced()
                    }
                    .font(.footnote)

                    Spacer()
                }
            }
            .padding()
            .presentationDetents([.medium])
        })
    }
}

#Preview {
    Form {
        ConnectionSettingsView(configViewModel: ConfigViewModel(), headerLabel: "GitHub Connection")
    }
    .formStyle(.grouped)
    .background(.windowBackground)
}
