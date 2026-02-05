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

        // Check file exists and has content
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw AudioConverterError.inputFileNotFound
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as? Int64) ?? 0
        guard fileSize > 0 else {
            throw AudioConverterError.inputFileEmpty
        }

        // Use AVAudioFile to read the CAF and write as M4A with AAC encoding
        let inputFile = try AVAudioFile(forReading: inputURL)
        let processingFormat = inputFile.processingFormat

        guard processingFormat.sampleRate > 0 && processingFormat.channelCount > 0 else {
            throw AudioConverterError.noAudioTracks
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: processingFormat.sampleRate,
            AVNumberOfChannelsKey: processingFormat.channelCount,
            AVEncoderBitRateKey: 128_000,
        ]

        try? FileManager.default.removeItem(at: outputURL)

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputSettings,
            commonFormat: processingFormat.commonFormat,
            interleaved: processingFormat.isInterleaved
        )

        let bufferCapacity: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat,
            frameCapacity: bufferCapacity
        ) else {
            throw AudioConverterError.conversionFailed("Failed to allocate audio buffer")
        }

        while inputFile.framePosition < inputFile.length {
            try inputFile.read(into: buffer)
            try outputFile.write(from: buffer)
        }

        return outputURL
    }
}

enum AudioConverterError: LocalizedError {
    case inputFileNotFound
    case inputFileEmpty
    case noAudioTracks
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .inputFileNotFound:
            return "Audio file not found for conversion"
        case .inputFileEmpty:
            return "Audio file is empty - recording may have failed"
        case .noAudioTracks:
            return "Audio file contains no audio tracks"
        case .conversionFailed(let reason):
            return "Audio conversion failed: \(reason)"
        }
    }
}
