import SwiftUI

struct ConnectionSettingsView<AdditionalContent: View>: View {
    @ObservedObject var configViewModel: ConfigViewModel
    var headerLabel: LocalizedStringKey
    var additionalContent: AdditionalContent?

    @State private var showPopover = false

    init(
        configViewModel: ConfigViewModel,
        headerLabel: LocalizedStringKey,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent
    ) {
        self.configViewModel = configViewModel
        self.headerLabel = headerLabel
        self.additionalContent = additionalContent()
    }

    #if os(macOS)
        var sectionHeader: some View {
            Text(headerLabel)
        }

        var helpSheet: some View {
            EmptyView()
        }
    #else
        var sectionHeader: some View {
            HStack {
                Text(headerLabel)
                Button {
                    showPopover = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Quick help")
            }
        }

        var helpSheet: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("connection-settings.pat.label")
                            .font(.headline)
                        Text("connection-settings.pat.explanation")
                            .padding(.bottom)

                        Text("connection-settings.enterprise-url.label")
                            .font(.headline)
                        Text("connection-settings.enterprise-url.explanation")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle(headerLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showPopover = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    #endif

    var body: some View {
        Section {
            HelpTextField(type: .revealSecureField, text: $configViewModel.token, label: "connection-settings.pat.label", prompt: "Enter PAT") {
                VStack(alignment: .leading) {
                    Text("connection-settings.pat.explanation")
                }
                .padding()
                .frame(width: 300)
            }
            .disableAutoCapitalization()
            .autocorrectionDisabled()
            #if os(iOS)
                .keyboardType(.asciiCapable)
            #endif

            Toggle(isOn: $configViewModel.useGitHubEnterprise) {
                Text("Use GitHub Enterprise")
            }
            .toggleStyle(.switch)

            if configViewModel.useGitHubEnterprise {
                HelpTextField(type: .textField, text: $configViewModel.gitHubEnterpriseUrl, label: "connection-settings.enterprise-url.label", prompt: "https://github.acme.org") {
                    VStack(alignment: .leading) {
                        Text("connection-settings.enterprise-url.explanation")
                    }
                    .padding()
                }
                .disableAutoCapitalization()
                .disableAutocorrection(true)
                #if os(iOS)
                    .keyboardType(.URL)
                #endif
            }

            additionalContent
        } header: {
            sectionHeader
        }
        .sheet(isPresented: $showPopover, content: {
            helpSheet
        })
    }
}

extension ConnectionSettingsView where AdditionalContent == EmptyView {
    init(configViewModel: ConfigViewModel, headerLabel: LocalizedStringKey) {
        self.configViewModel = configViewModel
        self.headerLabel = headerLabel
    }
}

#Preview {
    Form {
        ConnectionSettingsView(configViewModel: ConfigViewModel(), headerLabel: "GitHub Connection")
        ConnectionSettingsView(configViewModel: ConfigViewModel(), headerLabel: "GitHub Connection") {
            Text("Additional Content")
        }
    }
    .formStyle(.grouped)
    .background(.windowBackground)
}
