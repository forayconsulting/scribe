import AVFoundation
import Foundation

actor AudioFileWriter {
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var isWriting = false
    private let outputURL: URL

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func startWriting(sourceFormat: CMFormatDescription) throws {
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]

        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: sourceFormat)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw AudioFileWriterError.cannotAddInput
        }

        writer.add(input)

        guard writer.startWriting() else {
            throw AudioFileWriterError.failedToStart(writer.error)
        }

        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.audioInput = input
        self.isWriting = true
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isWriting,
              let input = audioInput,
              input.isReadyForMoreMediaData else {
            return
        }

        input.append(sampleBuffer)
    }

    func finishWriting() async throws -> URL {
        guard isWriting, let writer = assetWriter else {
            // If never started writing, just return the URL (file won't exist)
            return outputURL
        }

        audioInput?.markAsFinished()

        await writer.finishWriting()

        if let error = writer.error {
            throw AudioFileWriterError.writingFailed(error)
        }

        isWriting = false
        assetWriter = nil
        audioInput = nil

        return outputURL
    }

    var hasStartedWriting: Bool {
        isWriting
    }
}

enum AudioFileWriterError: LocalizedError {
    case cannotAddInput
    case failedToStart(Error?)
    case notWriting
    case writingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .cannotAddInput:
            return "Cannot add audio input to asset writer"
        case .failedToStart(let error):
            return "Failed to start writing: \(error?.localizedDescription ?? "unknown error")"
        case .notWriting:
            return "Writer is not currently writing"
        case .writingFailed(let error):
            return "Writing failed: \(error.localizedDescription)"
        }
    }
}
