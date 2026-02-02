import AVFoundation
import Foundation

actor MicrophoneCaptureService {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var isCapturing = false

    static func hasPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func startCapturing(outputURL: URL) throws {
        guard !isCapturing else {
            throw MicrophoneCaptureError.alreadyCapturing
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Get the hardware's native format - this is what the mic provides
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw MicrophoneCaptureError.invalidAudioFormat
        }

        // Remove any existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Create audio file that matches input format exactly
        // Using .caf format which supports any audio format natively
        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: recordingFormat.settings
        )

        // Install tap to receive audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak audioFile] buffer, _ in
            guard let audioFile = audioFile else { return }
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing audio buffer: \(error)")
            }
        }

        // Start the engine
        try engine.start()

        self.audioEngine = engine
        self.audioFile = audioFile
        self.outputURL = outputURL
        self.isCapturing = true
    }

    func stopCapturing() -> URL? {
        guard isCapturing else { return nil }

        // Remove tap first
        audioEngine?.inputNode.removeTap(onBus: 0)

        // Stop the engine
        audioEngine?.stop()

        // Get the URL before clearing
        let url = outputURL

        // Clear state
        audioFile = nil
        audioEngine = nil
        outputURL = nil
        isCapturing = false

        return url
    }

    var capturing: Bool {
        isCapturing
    }
}

enum MicrophoneCaptureError: LocalizedError {
    case alreadyCapturing
    case notCapturing
    case permissionDenied
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "Already capturing microphone audio"
        case .notCapturing:
            return "Not currently capturing microphone audio"
        case .permissionDenied:
            return "Microphone permission denied"
        case .invalidAudioFormat:
            return "Invalid audio format from microphone"
        }
    }
}
