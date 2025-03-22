import SwiftUI

struct ShareView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    let onDismiss: () -> Void

    @State private var qrCodeImage: Image?
    @State private var isGeneratingQrCode = false
    @State private var qrCodeError: Error?
    @State private var revealQrCode = false

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
    
    private var revealText: Text {
        #if os(macOS)
        Text("Click to reveal")
        #else
        Text("Tap to reveal")
        #endif
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
                ZStack {
                    image
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .blur(radius: revealQrCode ? 0 : 8)
                        .animation(.easeInOut(duration: 0.6), value: !revealQrCode)
                        .padding(20)
                        .onTapGesture {
                            revealQrCode.toggle()
                        }
                    revealText
                        .font(.title2)
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .shadow(color: .black, radius: 0, x: -1, y: -1)
                        .shadow(color: .black, radius: 0, x: 1, y: -1)
                        .shadow(color: .black, radius: 0, x: -1, y: 1)
                        .opacity(revealQrCode ? 0 : 1)
                        .animation(revealQrCode ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.3).delay(0.3), value: !revealQrCode)
                }
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
            .padding()
    }
}
