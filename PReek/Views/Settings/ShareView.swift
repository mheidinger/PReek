import SwiftUI

struct ShareView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    let onDismiss: () -> Void

    @State private var qrCodeImage: Image?
    @State private var isGeneratingQrCode = false
    @State private var qrCodeError: Error?

    private func generateQRCode() async {
        qrCodeError = nil
        isGeneratingQrCode = true

        do {
            let shareData = configViewModel.getShareData()
            guard let shareData else {
                throw AppError.missingConfigToShare
            }

            let image = try await Task.detached(priority: .userInitiated) {
                try generateJsonQrCode(from: shareData)
            }.value

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
        VStack {
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
                Text("Scan this QR code in the PReek App on another device to import your configuration.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 3)
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }

            Spacer()

            Text("""
            Shared Configuration includes:
            - Your GitHub token
            - If provided the GitHub Enterprise URL
            """)
            .font(.footnote)
        }
        .padding(.horizontal)
        .onAppear {
            Task {
                await generateQRCode()
            }
        }
        .presentationDetents([.medium])
        .toolbar {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.large)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShareView(configViewModel: ConfigViewModel(), onDismiss: {})
    }
}
