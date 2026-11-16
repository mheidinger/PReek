import SwiftUI

struct ExcludedUsersScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    @State private var newExcludedUsername = ""

    private var trimmedUsername: String {
        newExcludedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addExcludedUser() {
        guard !trimmedUsername.isEmpty else { return }
        configViewModel.addExcludedUser(username: trimmedUsername)
        newExcludedUsername = ""
    }

    var body: some View {
        Form {
            Section {
                ForEach(configViewModel.excludedUsers) { excludedUser in
                    Text(excludedUser.username)
                }
                .onDelete(perform: configViewModel.removeExcludedUserByIndexSet)

                HStack {
                    TextField("Username", text: $newExcludedUsername, prompt: Text("Add Username"))
                        .autocorrectionDisabled()
                        .disableAutoCapitalization()
                        .onSubmit(addExcludedUser)
                    #if os(iOS)
                        .submitLabel(.done)
                    #endif
                    Button(action: addExcludedUser) {
                        Image(systemName: "plus")
                        #if os(iOS)
                            .frame(minWidth: 44, minHeight: 44)
                        #endif
                    }
                    .accessibilityLabel("Add Username")
                    .buttonStyle(.borderless)
                    .disabled(trimmedUsername.isEmpty)
                }
            } footer: {
                Text("Don't show PRs that only have been contributed to by these users")
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        #endif
        .background(.windowBackground)
        .navigationTitle("Excluded Users")
    }
}

#Preview {
    NavigationStack {
        ExcludedUsersScreen(configViewModel: ConfigViewModel())
    }
}
