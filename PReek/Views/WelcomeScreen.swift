import SwiftUI

struct WelcomeScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var testConnection: () async -> Error?
    var dismissWelcomeView: () async -> Void

    @State private var error: Error?

    private func doSave() {
        Task {
            configViewModel.saveSettings()
            error = await testConnection()
            if error == nil {
                await dismissWelcomeView()
            }
        }
    }

    var body: some View {
        VStack {
            headerView

            formView
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HoverableLink("Made by Max Heidinger", destination: URL(string: "https://github.com/mheidinger/PReek")!)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .background(.windowBackground)
    }

    #if os(macOS)
        private var headerView: some View {
            HStack(spacing: 30) {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60)
                VStack {
                    Text("welcome.title")
                        .font(.largeTitle)
                    Text("welcome.subtitle")
                        .font(.title)
                }
            }
            .padding(.top, 25)
        }
    #else
        private var headerView: some View {
            VStack {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                VStack {
                    Text("welcome.title")
                        .font(.largeTitle)
                    Text("welcome.subtitle")
                        .font(.title)
                }
            }
            .padding(.top, 25)
        }
    #endif

    private var formView: some View {
        Form {
            ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "Required Settings") {
                HStack {
                    Spacer()
                    Button(action: doSave) {
                        Text("Continue")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = error {
                VStack {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    WelcomeScreen(configViewModel: ConfigViewModel(), testConnection: { AppError.forbidden }, dismissWelcomeView: {})
    #if os(macOS)
        .frame(width: 600, height: 400)
    #endif
}
