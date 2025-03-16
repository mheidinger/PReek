import OSLog
import SwiftUI
#if os(iOS)
    import CodeScanner
#endif

private let simulatorQrCodeData = """
{"version": 1, "token": "my-token", "gitHubEnterpriseUrl": "https://github.acme.com"}
"""

struct ImportSheetModifier: ViewModifier {
    @ObservedObject var configViewModel: ConfigViewModel
    @Binding var isPresented: Bool

    #if os(iOS)
        @State private var showImportErrorAlert: Bool = false
        @State private var importError: Error?

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $isPresented, onDismiss: { showImportErrorAlert = importError != nil }) {
                    NavigationStack {
                        VStack(alignment: .leading) {
                            Text("Open PReek on another device and click on \"Share\" in the settings.")
                            CodeScannerView(
                                codeTypes: [.qr],
                                simulatedData: simulatorQrCodeData,
                                completion: handleScan
                            )
                        }
                        .padding(.horizontal)
                        .navigationTitle("Import Configuration")
                        .toolbar {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                            }
                        }
                    }
                }
                .alert(isPresented: $showImportErrorAlert) {
                    Alert(
                        title: Text(importError?.localizedDescription ?? "Unknown error"),
                        message: (importError as? LocalizedError)?.recoverySuggestion.map { value in Text(value) },
                        dismissButton: .default(Text("OK"))
                    )
                }
        }

        private func handleScan(result: Result<ScanResult, ScanError>) {
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
