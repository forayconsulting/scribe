import Foundation
import SwiftUI

@MainActor
@Observable
final class RecordingViewModel {
    var state: RecordingState = .idle
    var hasPermission: Bool = false
    var hasMicPermission: Bool = false
    var hasAPIKey: Bool = false
    var showSettings: Bool = false
    var meetingTitle: String = ""

    private let audioCaptureService = AudioCaptureService()
    private let transcriptionService = TranscriptionService()
    private let markdownFormatter = MarkdownFormatter()
    private let transcriptionMerger = TranscriptionMerger()
    private let audioConverter = AudioConverter()

    private var recordingTimer: Timer?
    private var captureResult: AudioCaptureResult?

    var recordingDuration: TimeInterval {
        guard case .recording(let startTime) = state else { return 0 }
        return Date().timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let duration = recordingDuration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    init() {
        checkPermissions()
        Task {
            await checkAPIKey()
        }
    }

    func checkPermissions() {
        hasPermission = AudioCaptureService.hasPermission()
        hasMicPermission = AudioCaptureService.hasMicrophonePermission()
    }

    func requestPermission() {
        _ = AudioCaptureService.requestPermission()
        checkPermissions()
    }

    func requestMicPermission() async {
        _ = await AudioCaptureService.requestMicrophonePermission()
        checkPermissions()
    }

    func checkAPIKey() async {
        do {
            let key = try await KeychainService.shared.getAPIKey()
            hasAPIKey = key != nil && !key!.isEmpty
        } catch {
            hasAPIKey = false
        }
    }

    func startRecording() async {
        guard hasPermission else {
            requestPermission()
            return
        }

        if !hasMicPermission {
            await requestMicPermission()
            guard hasMicPermission else { return }
        }

        guard hasAPIKey else {
            showSettings = true
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        do {
            try await audioCaptureService.startCapturing(outputURL: tempURL)
            state = .recording(startTime: Date())
        } catch {
            state = .error(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() async {
        guard case .recording = state else { return }

        do {
            let result = try await audioCaptureService.stopCapturing()
            captureResult = result
            await processRecording()
        } catch {
            state = .error(message: "Failed to stop recording: \(error.localizedDescription)")
        }
    }

    private func processRecording() async {
        guard let result = captureResult else {
            state = .error(message: "No audio files to process")
            return
        }

        // Debug: Log which audio files we have
        print("[Scribe Debug] Mic URL: \(result.micAudioURL?.path ?? "nil")")
        print("[Scribe Debug] System URL: \(result.systemAudioURL?.path ?? "nil")")

        guard result.micAudioURL != nil || result.systemAudioURL != nil else {
            state = .error(message: "No audio was captured")
            return
        }

        state = .processing(progress: 0, status: "Preparing...")

        do {
            guard let apiKey = try await KeychainService.shared.getAPIKey() else {
                state = .error(message: "No API key configured")
                return
            }

            // Get speaker name from settings
            let micSpeakerName = UserDefaults.standard.string(forKey: "micSpeakerName") ?? "Me"
            print("[Scribe Debug] Mic speaker name from settings: '\(micSpeakerName)'")

            var micTranscription: TranscriptionResult?
            var systemTranscription: TranscriptionResult?

            // Transcribe mic audio (0-45% progress)
            if let micURL = result.micAudioURL {
                state = .processing(progress: 0, status: "Converting microphone audio...")

                // Convert CAF to M4A for API compatibility
                let convertedMicURL = try await audioConverter.convertToM4A(inputURL: micURL)
                print("[Scribe Debug] Converted mic audio to: \(convertedMicURL.path)")

                state = .processing(progress: 0.05, status: "Transcribing microphone...")
                micTranscription = try await transcriptionService.transcribe(
                    audioURL: convertedMicURL,
                    apiKey: apiKey,
                    source: .microphone(speakerName: micSpeakerName),
                    progressHandler: { [weak self] progress, status in
                        Task { @MainActor in
                            let scaledProgress = 0.05 + (progress * 0.40)
                            self?.state = .processing(progress: scaledProgress, status: "Mic: \(status)")
                        }
                    }
                )
                print("[Scribe Debug] Mic transcription: \(micTranscription?.segments.count ?? 0) segments")
                if let first = micTranscription?.segments.first {
                    print("[Scribe Debug] First mic segment speaker: '\(first.speaker ?? "nil")'")
                }

                // Clean up converted file if different from original
                if convertedMicURL != micURL {
                    try? FileManager.default.removeItem(at: convertedMicURL)
                }
            }

            // Transcribe system audio (45-90% progress)
            if let sysURL = result.systemAudioURL {
                state = .processing(progress: 0.45, status: "Transcribing system audio...")
                systemTranscription = try await transcriptionService.transcribe(
                    audioURL: sysURL,
                    apiKey: apiKey,
                    source: .systemAudio,
                    progressHandler: { [weak self] progress, status in
                        Task { @MainActor in
                            let scaledProgress = 0.45 + (progress * 0.45)
                            self?.state = .processing(progress: scaledProgress, status: "System: \(status)")
                        }
                    }
                )
                print("[Scribe Debug] System transcription: \(systemTranscription?.segments.count ?? 0) segments")
                if let first = systemTranscription?.segments.first {
                    print("[Scribe Debug] First system segment speaker: '\(first.speaker ?? "nil")'")
                }
            }

            // Merge transcriptions (90-100% progress)
            state = .processing(progress: 0.90, status: "Merging transcripts...")

            guard let mergedResult = transcriptionMerger.merge(
                micResult: micTranscription,
                systemResult: systemTranscription
            ) else {
                state = .error(message: "Failed to merge transcription results")
                return
            }

            state = .processing(progress: 0.95, status: "Formatting...")

            let markdown = markdownFormatter.format(mergedResult, meetingTitle: meetingTitle.isEmpty ? nil : meetingTitle)
            let suggestedFilename = markdownFormatter.suggestFilename(for: meetingTitle.isEmpty ? nil : meetingTitle)

            if let savedURL = await saveMarkdown(markdown, suggestedFilename: suggestedFilename) {
                state = .complete(transcriptURL: savedURL)
            } else {
                state = .idle
            }

            // Clean up temp files
            if let micURL = result.micAudioURL {
                try? FileManager.default.removeItem(at: micURL)
            }
            if let sysURL = result.systemAudioURL {
                try? FileManager.default.removeItem(at: sysURL)
            }
            captureResult = nil
            meetingTitle = ""

        } catch {
            state = .error(message: "Transcription failed: \(error.localizedDescription)")
        }
    }

    private func saveMarkdown(_ content: String, suggestedFilename: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else {
            return nil
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            state = .error(message: "Failed to save file: \(error.localizedDescription)")
            return nil
        }
    }

    func reset() {
        state = .idle
        meetingTitle = ""
    }

    func openTranscript() {
        guard case .complete(let url) = state else { return }
        NSWorkspace.shared.open(url)
    }
}
