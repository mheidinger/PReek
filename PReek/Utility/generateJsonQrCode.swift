import CoreImage.CIFilterBuiltins
import OSLog
import SwiftUI

func generateJsonQrCode<FromType: Codable>(from: FromType) -> Image {
    let logger = Logger()
    let fallbackImage = Image(systemName: "xmark.circle")

    do {
        let cgImage = try generateJsonQrCodeCgImage(from: from)

        #if os(macOS)
            return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #else
            return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    } catch {
        logger.error("Failed to generate QR Code: \(error.localizedDescription)")
        return fallbackImage
    }
}

private func generateJsonQrCodeCgImage<FromType: Codable>(from: FromType) throws -> CGImage {
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(from)

    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(jsonData)

    if let outputImage = filter.outputImage {
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return cgImage
        }
    }

    throw AppError.qrCodeGenerationFailed
}
