import SwiftUI

struct WelcomeView: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var testConnection: () async -> Error?
    var dismissWelcomeView: () -> Void

    @State private var error: Error?

    private func doSave() {
        Task {
            configViewModel.saveSettings()
            error = await testConnection()
            if error == nil {
                dismissWelcomeView()
            }
        }
    }

    var body: some View {
        VStack(spacing: 50) {
            HStack(spacing: 30) {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60)
                VStack {
                    Text("Welcome to PReek")
                        .font(.largeTitle)
                    Text("Let's get you started!")
                        .font(.title)
                }
            }

            VStack(alignment: .trailing) {
                ConnectionSettingsView(configViewModel: configViewModel)

                Button(action: doSave) {
                    Text("Save")
                }

                if let error = error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 150, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            ModifierLink(destination: URL(string: "https://github.com/mheidinger/PReek")!) {
                Text("Made by Max Heidinger")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    WelcomeView(configViewModel: ConfigViewModel(), testConnection: { GitHubError.forbidden }, dismissWelcomeView: {})
        .frame(width: 600, height: 400)
}
