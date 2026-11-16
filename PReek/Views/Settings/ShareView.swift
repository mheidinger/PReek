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

    var body: some View {
        #if os(iOS)
            iOSContent
        #else
            macOSContent
        #endif
    }

    #if os(iOS)
        private var iOSContent: some View {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Scan this QR code in the PReek App on another device to import your configuration.")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Label("The QR code includes your GitHub token. Only share it with a device you trust.", systemImage: "lock.shield")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isGeneratingQrCode {
                        ProgressView()
                            .frame(height: 180)
                    } else if let error = qrCodeError {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    } else if let image = qrCodeImage {
                        if revealQrCode {
                            image
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 240, maxHeight: 240)
                                .padding(12)
                                .background(.white)
                                .accessibilityLabel("Configuration QR code")
                                .privacySensitive()
                            Button("Hide QR Code") {
                                revealQrCode = false
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Show QR Code", systemImage: "qrcode") {
                                revealQrCode = true
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(minHeight: 180)
                        }
                    }

                    Text("""
                    Shared Configuration includes:
                    - Your GitHub token
                    - If provided the GitHub Enterprise URL
                    - PR fetch and remove config values
                    - Excluded Users
                    """)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Share Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .task {
                await generateQRCode()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    #else
        private var macOSContent: some View {
            VStack {
                Text("Scan this QR code in the PReek App on another device to import your configuration.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 3)
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
                    ZStack {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .blur(radius: revealQrCode ? 0 : 5)
                            .animation(.easeInOut(duration: 0.6), value: !revealQrCode)
                            .padding(5)
                        Text("Tap to reveal")
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
                    .onTapGesture {
                        revealQrCode.toggle()
                    }
                }

                Spacer()

                Text("""
                Shared Configuration includes:
                - Your GitHub token
                - If provided the GitHub Enterprise URL
                - PR fetch and remove config values
                - Excluded Users
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    #endif
}

#Preview {
    NavigationStack {
        ShareView(configViewModel: ConfigViewModel(), onDismiss: {})
            .padding()
    }
}
