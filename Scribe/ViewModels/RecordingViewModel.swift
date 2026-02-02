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

    private var recordingTimer: Timer?
    private var audioFileURL: URL?

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
            audioFileURL = tempURL
            state = .recording(startTime: Date())
        } catch {
            state = .error(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() async {
        guard case .recording = state else { return }

        do {
            let outputURL = try await audioCaptureService.stopCapturing()
            audioFileURL = outputURL
            await processRecording()
        } catch {
            state = .error(message: "Failed to stop recording: \(error.localizedDescription)")
        }
    }

    private func processRecording() async {
        guard let audioURL = audioFileURL else {
            state = .error(message: "No audio file to process")
            return
        }

        state = .processing(progress: 0, status: "Preparing...")

        do {
            guard let apiKey = try await KeychainService.shared.getAPIKey() else {
                state = .error(message: "No API key configured")
                return
            }

            let result = try await transcriptionService.transcribe(
                audioURL: audioURL,
                apiKey: apiKey,
                progressHandler: { [weak self] progress, status in
                    Task { @MainActor in
                        self?.state = .processing(progress: progress, status: status)
                    }
                }
            )

            let markdown = markdownFormatter.format(result, meetingTitle: meetingTitle.isEmpty ? nil : meetingTitle)
            let suggestedFilename = markdownFormatter.suggestFilename(for: meetingTitle.isEmpty ? nil : meetingTitle)

            if let savedURL = await saveMarkdown(markdown, suggestedFilename: suggestedFilename) {
                state = .complete(transcriptURL: savedURL)
            } else {
                state = .idle
            }

            try? FileManager.default.removeItem(at: audioURL)
            audioFileURL = nil
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
