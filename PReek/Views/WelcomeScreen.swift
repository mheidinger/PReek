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
        VStack(spacing: 15) {
            headerView

            formView

            errorAndContinue

            Spacer(minLength: 0)

            footerView
        }
        .background(.windowBackground)
    }

    private var headerView: some View {
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
        .padding(.top, 50)
    }

    private var formView: some View {
        Form {
            ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "Required Settings")
        }
        .formStyle(.grouped)
        .frame(maxHeight: 180)
    }

    private var errorAndContinue: some View {
        HStack(alignment: .top) {
            if let error = error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
            }

            Spacer()

            Button(action: doSave) {
                Text("Continue")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, -15)
        .padding(.horizontal, 20)
    }

    private var footerView: some View {
        HoverableLink("Made by Max Heidinger", destination: URL(string: "https://github.com/mheidinger/PReek")!)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.bottom)
    }
}

#Preview {
    WelcomeScreen(configViewModel: ConfigViewModel(), testConnection: { AppError.forbidden }, dismissWelcomeView: {})
    #if os(macOS)
        .frame(width: 600, height: 400)
    #endif
}
