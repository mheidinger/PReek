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
    @State private var isSaving = false

    var importTip = ImportTip()

    private func doSave() {
        guard !isSaving, !configViewModel.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            configViewModel.saveSettings()
            error = await testConnection()
            if error == nil {
                await dismissWelcomeView()
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
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
                #else
                    formView
                        .scrollDismissesKeyboard(.interactively)
                #endif
            }
            .background(.windowBackground)
            #if os(iOS)
                // Not shown on macOS - https://stackoverflow.com/questions/77647716/macos-swiftui-using-navigationstack-toolbar-button-not-showing-in-menubarextra-a
                .toolbar {
                    Button("Import Configuration", systemImage: "qrcode.viewfinder") {
                        showImportSheet = true
                        importTip.invalidate(reason: .actionPerformed)
                    }
                    .disabled(isSaving)
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
                titleAndSubtitle
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
                    .accessibilityHidden(true)
                titleAndSubtitle
            }
            .padding(.top, 25)
            .multilineTextAlignment(.center)
        }
    #endif

    private var titleAndSubtitle: some View {
        VStack {
            Text("welcome.title")
                .font(.largeTitle)
            Text("welcome.subtitle")
                .font(.title)
        }
    }

    private var formView: some View {
        Form {
            #if os(iOS)
                Section {
                    headerView
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            #endif
            ConnectionSettingsView(configViewModel: configViewModel, headerLabel: "Required Settings") {
                #if os(macOS)
                    HStack {
                        Spacer()
                        continueButton
                    }
                #endif
            }
            .disabled(isSaving)

            #if os(iOS)
                Section {
                    continueButton
                }
            #endif

            if let error = error {
                VStack {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundStyle(.red)
                }
            }

            #if os(iOS)
                Section {
                    HoverableLink("Made by Max Heidinger", destination: URL(string: "https://github.com/mheidinger/PReek")!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            #endif
        }
        .formStyle(.grouped)
    }

    private var continueButton: some View {
        Button(action: doSave) {
            HStack {
                Text("Continue")
                if isSaving {
                    ProgressView()
                        .accessibilityLabel("Testing connection")
                }
            }
            #if os(iOS)
            .frame(maxWidth: .infinity)
            #endif
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving || configViewModel.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

#Preview {
    WelcomeScreen(configViewModel: ConfigViewModel(), testConnection: { AppError.forbidden }, dismissWelcomeView: {})
        .onAppear {
            try? Tips.configure()
            Tips.showAllTipsForTesting()
        }
    #if os(macOS)
        .frame(width: 600, height: 400)
    #endif
}
