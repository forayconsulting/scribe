import AVFoundation
import Foundation
@preconcurrency import ScreenCaptureKit

struct AudioCaptureResult {
    let micAudioURL: URL?
    let systemAudioURL: URL?
}

actor AudioCaptureService {
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private var audioWriter: AudioFileWriter?
    private var isCapturing = false

    // Mic capture components
    private var micEngine: AVAudioEngine?
    private var micFile: AVAudioFile?
    private var micFileURL: URL?

    // Output URLs
    private var systemAudioURL: URL?
    private var finalOutputURL: URL?

    static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func startCapturing(outputURL: URL) async throws {
        guard !isCapturing else {
            throw AudioCaptureError.alreadyCapturing
        }

        self.finalOutputURL = outputURL

        // Create temp URLs for separate streams
        let tempDir = FileManager.default.temporaryDirectory
        let sessionID = UUID().uuidString
        let sysURL = tempDir.appendingPathComponent("sys_\(sessionID).m4a")
        let micURL = tempDir.appendingPathComponent("mic_\(sessionID).caf")

        self.systemAudioURL = sysURL
        self.micFileURL = micURL

        // Start system audio capture via ScreenCaptureKit
        try await startSystemAudioCapture(outputURL: sysURL)

        // Start microphone capture via AVAudioEngine
        if Self.hasMicrophonePermission() {
            try startMicrophoneCapture(outputURL: micURL)
        }

        self.isCapturing = true
    }

    private func startSystemAudioCapture(outputURL: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()

        // System audio only - we capture mic separately for reliability
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        // Minimal video (required by ScreenCaptureKit)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let writer = AudioFileWriter(outputURL: outputURL)
        let output = AudioStreamOutput(writer: writer)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))

        try await stream.startCapture()

        self.stream = stream
        self.streamOutput = output
        self.audioWriter = writer
    }

    private func startMicrophoneCapture(outputURL: URL) throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw AudioCaptureError.microphonePermissionDenied
        }

        try? FileManager.default.removeItem(at: outputURL)

        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: recordingFormat.settings
        )

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak audioFile] buffer, _ in
            guard let audioFile = audioFile else { return }
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Error writing mic buffer: \(error)")
            }
        }

        try engine.start()

        self.micEngine = engine
        self.micFile = audioFile
    }

    func stopCapturing() async throws -> AudioCaptureResult {
        guard isCapturing, let stream = stream, let writer = audioWriter else {
            throw AudioCaptureError.notCapturing
        }

        // Stop system audio
        try await stream.stopCapture()
        let sysURL = try await writer.finishWriting()

        // Stop mic audio - remove tap first to stop writing
        micEngine?.inputNode.removeTap(onBus: 0)
        micEngine?.stop()
        let micURL = micFileURL

        // Release the audio file to ensure it's properly closed and flushed
        micFile = nil
        micEngine = nil

        // Give the file system a moment to flush the audio file
        try await Task.sleep(for: .milliseconds(100))

        self.stream = nil
        self.streamOutput = nil
        self.audioWriter = nil
        self.isCapturing = false

        // Check if mic file is valid (exists and has content)
        var validMicURL: URL? = nil
        if let micURL = micURL, FileManager.default.fileExists(atPath: micURL.path) {
            let micSize = (try? FileManager.default.attributesOfItem(atPath: micURL.path)[.size] as? Int64) ?? 0
            if micSize > 0 {
                validMicURL = micURL
            } else {
                try? FileManager.default.removeItem(at: micURL)
            }
        }

        // Check if system file is valid
        var validSysURL: URL? = nil
        if FileManager.default.fileExists(atPath: sysURL.path) {
            let sysSize = (try? FileManager.default.attributesOfItem(atPath: sysURL.path)[.size] as? Int64) ?? 0
            if sysSize > 0 {
                validSysURL = sysURL
            } else {
                try? FileManager.default.removeItem(at: sysURL)
            }
        }

        return AudioCaptureResult(micAudioURL: validMicURL, systemAudioURL: validSysURL)
    }
}

private final class AudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let writer: AudioFileWriter
    private var hasStartedWriting = false
    private let lock = NSLock()

    init(writer: AudioFileWriter) {
        self.writer = writer
        super.init()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard sampleBuffer.isValid else { return }

        lock.lock()
        let needsStart = !hasStartedWriting
        if needsStart {
            hasStartedWriting = true
        }
        lock.unlock()

        Task {
            if needsStart {
                if let formatDescription = sampleBuffer.formatDescription {
                    try? await writer.startWriting(sourceFormat: formatDescription)
                }
            }
            await writer.appendSampleBuffer(sampleBuffer)
        }
    }
}

enum AudioCaptureError: LocalizedError {
    case alreadyCapturing
    case notCapturing
    case noDisplayFound
    case permissionDenied
    case microphonePermissionDenied
    case noAudioCaptured
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "Already capturing audio"
        case .notCapturing:
            return "Not currently capturing audio"
        case .noDisplayFound:
            return "No display found for capture"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .noAudioCaptured:
            return "No audio was captured"
        case .exportFailed:
            return "Failed to export audio"
        }
    }
}
