import CoreImage.CIFilterBuiltins
import OSLog
import SwiftUI

func generateJsonQrCode<FromType: Codable>(from: FromType) throws -> Image {
    let logger = Logger()

    do {
        let cgImage = try generateJsonQrCodeCgImage(from: from)

        #if os(macOS)
            return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #else
            return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    } catch {
        logger.error("Failed to generate QR Code: \(error)")
        throw AppError.qrCodeGenerationFailed
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
