import OSLog
import SwiftUI
#if os(iOS)
    import CodeScanner
#endif

struct ImportSheetModifier: ViewModifier {
    @ObservedObject var configViewModel: ConfigViewModel
    @Binding var isPresented: Bool
    @Environment(\.offlineImportData) private var offlineImportData

    #if os(iOS)
        @State private var showImportErrorAlert: Bool = false
        @State private var importError: Error?
        @State private var isHandlingScan = false

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $isPresented, onDismiss: { showImportErrorAlert = importError != nil }) {
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Open PReek on your other device:\n\nMac: Settings → GitHub → Show QR Code.\niPhone or iPad: Settings → Share button → Show QR Code.\n\nScan the QR code here to import your configuration.")
                                if let offlineImportData {
                                    Button("Import Configuration") {
                                        do {
                                            importError = nil
                                            try configViewModel.importShareData(offlineImportData)
                                        } catch {
                                            importError = error
                                        }
                                        isPresented = false
                                    }
                                } else {
                                    CodeScannerView(codeTypes: [.qr], completion: handleScan)
                                        .frame(height: 320)
                                }
                            }
                            .padding()
                        }
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle("Import Configuration")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
                .onChange(of: isPresented) { _, presented in
                    if presented {
                        importError = nil
                        showImportErrorAlert = false
                        isHandlingScan = false
                    }
                }
                .alert(isPresented: $showImportErrorAlert) {
                    Alert(
                        title: Text(importError?.localizedDescription ?? String(localized: "Unknown error")),
                        message: (importError as? LocalizedError)?.recoverySuggestion.map { value in Text(value) },
                        dismissButton: .default(Text("OK")) {
                            importError = nil
                        }
                    )
                }
        }

        private func handleScan(result: Result<ScanResult, ScanError>) {
            guard isPresented, !isHandlingScan else { return }
            isHandlingScan = true
            importError = nil
            do {
                switch result {
                case let .success(result):
                    try configViewModel.importShareData(result.string.data(using: .utf8) ?? Data())
                case let .failure(error):
                    Logger().error("Failed to scan QR Code: \(error)")
                    throw AppError.failedToImportShareData
                }
            } catch {
                importError = error
            }

            isPresented = false
        }
    #else
        func body(content: Content) -> some View {
            content
        }
    #endif
}

extension View {
    func importSheet(configViewModel: ConfigViewModel, isPresented: Binding<Bool>) -> some View {
        modifier(ImportSheetModifier(configViewModel: configViewModel, isPresented: isPresented))
    }
}

#Preview {
    Text("Content")
        .importSheet(configViewModel: ConfigViewModel(), isPresented: .constant(true))
}
