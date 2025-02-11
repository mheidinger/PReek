import SwiftUI

struct ExcludedUsersScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    @State private var newExcludedUsername = ""

    private func addExcludedUser() {
        configViewModel.addExcludedUser(username: newExcludedUsername)
        newExcludedUsername = ""
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(configViewModel.excludedUsers) { excludedUser in
                        Text("\(excludedUser.username)")
                    }
                    .onDelete(perform: configViewModel.removeExcludedUserByIndexSet)

                    TextField("Username", text: $newExcludedUsername, prompt: Text("Add Username"))
                        .autocorrectionDisabled()
                        .disableAutoCapitalization()
                        .safeAreaInset(edge: .trailing) {
                            Button(action: addExcludedUser) {
                                Image(systemName: "plus")
                            }
                        }
                }
            } footer: {
                Text("Don't show PRs that only have been contributed to by these users")
            }
        }
        #if os(iOS)
        .toolbar { EditButton() }
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
