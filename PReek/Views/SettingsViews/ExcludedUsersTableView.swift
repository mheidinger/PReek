import SwiftUI

struct ExcludedUsersTableView: View {
    @ObservedObject var configViewModel: ConfigViewModel

    @State private var newExcludedUserName: String = ""

    func add() {
        let trimmedUsername = newExcludedUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUsername.isEmpty {
            return
        }
        configViewModel.addExcludedUser(username: trimmedUsername)
        newExcludedUserName = ""
    }

    var body: some View {
        Section {
            Table(configViewModel.excludedUsers) {
                TableColumn("Username", value: \.username)
                TableColumn("Remove") { user in
                    Button(action: { configViewModel.removeExcludedUser(user) }) {
                        Image(systemName: "minus")
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .foregroundColor(.red)
                }
                .alignment(.trailing)
            }
            .tableColumnHeaders(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 5) {
                        TextField("Username", text: $newExcludedUserName, prompt: Text("Add Username"))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                        Button(action: add) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                }
                .background(Color(nsColor: .tertiarySystemFill))
            }
        } header: {
            VStack(alignment: .leading) {
                Text("Excluded Users")
                Text("Don't show PRs that only have been contributed to by these users")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Form {
        Section {
            ExcludedUsersTableView(configViewModel: ConfigViewModel())
        }
    }
    .formStyle(.grouped)
}
