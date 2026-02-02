import AVFoundation
import Foundation

struct AudioConverter {
    /// Converts an audio file to M4A format suitable for OpenAI API
    func convertToM4A(inputURL: URL) async throws -> URL {
        let outputURL = inputURL.deletingPathExtension().appendingPathExtension("m4a")

        // If already m4a, just return the input
        if inputURL.pathExtension.lowercased() == "m4a" {
            return inputURL
        }

        let asset = AVURLAsset(url: inputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioConverterError.failedToCreateExportSession
        }

        try? FileManager.default.removeItem(at: outputURL)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioConverterError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw AudioConverterError.exportIncomplete(exportSession.status)
        }

        return outputURL
    }
}

enum AudioConverterError: LocalizedError {
    case failedToCreateExportSession
    case exportFailed(Error)
    case exportIncomplete(AVAssetExportSession.Status)

    var errorDescription: String? {
        switch self {
        case .failedToCreateExportSession:
            return "Failed to create audio export session"
        case .exportFailed(let error):
            return "Audio conversion failed: \(error.localizedDescription)"
        case .exportIncomplete(let status):
            return "Audio conversion incomplete with status: \(status.rawValue)"
        }
    }
}
