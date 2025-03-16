import SwiftUI
import TipKit

struct ImportTip: Tip {
    var title: Text {
        Text("Import Configuration")
    }

    var message: Text? {
        Text("Import an existing configuration for another device running PReek.")
    }
}

struct WelcomeScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var testConnection: () async -> Error?
    var dismissWelcomeView: () async -> Void

    @State private var error: Error?
    @State private var showImportSheet: Bool = false

    var importTip = ImportTip()

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
        NavigationStack {
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
            #if os(iOS)
                // Not shown on macOS - https://stackoverflow.com/questions/77647716/macos-swiftui-using-navigationstack-toolbar-button-not-showing-in-menubarextra-a
                .toolbar {
                    Button(action: {
                        showImportSheet = true
                        importTip.invalidate(reason: .actionPerformed)
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .popoverTip(importTip)
                }
                .importSheet(configViewModel: configViewModel, isPresented: $showImportSheet)
            #endif
        }
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
                    Button("Continue", action: doSave)
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
    do {
        try Tips.configure()
        Tips.showAllTipsForTesting()
    } catch {
        print("Error initializing tips: \(error)")
    }

    return WelcomeScreen(configViewModel: ConfigViewModel(), testConnection: { AppError.forbidden }, dismissWelcomeView: {})
    #if os(macOS)
        .frame(width: 600, height: 400)
    #endif
}
