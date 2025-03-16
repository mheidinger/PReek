import SwiftUI

struct ShareView: View {
    let hideHeader: Bool
    let onDismiss: () -> Void

    @State private var qrCodeImage: Image?
    @State private var isGeneratingQrCode = false
    @State private var qrCodeError: Error?

    private func generateQRCode() async {
        // Reset previous state
        qrCodeError = nil
        isGeneratingQrCode = true

        // Move to background thread for processing
        do {
            let image = try await Task.detached(priority: .userInitiated) {
                try generateJsonQrCode(from: ConfigService.getShareData())
            }.value

            // Update UI on main thread
            await MainActor.run {
                qrCodeImage = image
                isGeneratingQrCode = false
            }
        } catch {
            await MainActor.run {
                qrCodeError = error
                isGeneratingQrCode = false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if !hideHeader {
                HStack {
                    Text("Share Configuration")
                        .font(.title)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.large)
                    }
                }

                Spacer()
            }

            HStack {
                Spacer()
                if isGeneratingQrCode {
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 200, height: 200)
                } else if let error = qrCodeError {
                    VStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                    }
                } else if let image = qrCodeImage {
                    image
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                }
                Spacer()
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .onAppear {
            Task {
                await generateQRCode()
            }
        }
    }
}

#Preview {
    ShareView(hideHeader: false, onDismiss: {})
}
