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
    private let audioConverter = AudioConverter()
    private let audioMerger = AudioMerger()
    private let sourceAttributor = AudioSourceAttributor()

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

        print("[Scribe Debug] Mic URL: \(result.micAudioURL?.path ?? "nil")")
        print("[Scribe Debug] System URL: \(result.systemAudioURL?.path ?? "nil")")

        guard result.micAudioURL != nil || result.systemAudioURL != nil else {
            state = .error(message: "No audio was captured")
            return
        }

        state = .processing(progress: 0, status: "Preparing audio...")

        do {
            guard let apiKey = try await KeychainService.shared.getAPIKey() else {
                state = .error(message: "No API key configured")
                return
            }

            let micSpeakerName = UserDefaults.standard.string(forKey: "micSpeakerName") ?? "Me"
            let tempDir = FileManager.default.temporaryDirectory

            // Convert mic audio to M4A if needed
            var micM4AURL: URL? = nil
            if let micURL = result.micAudioURL {
                state = .processing(progress: 0.05, status: "Converting microphone audio...")
                micM4AURL = try await audioConverter.convertToM4A(inputURL: micURL)
            }

            let sysURL = result.systemAudioURL

            // Determine what to transcribe
            var transcriptionURL: URL
            var needsAttribution = false

            if let micURL = micM4AURL, let systemURL = sysURL {
                // Both sources - merge them for single transcription
                state = .processing(progress: 0.10, status: "Merging audio tracks...")
                let mergedURL = tempDir.appendingPathComponent("merged_\(UUID().uuidString).m4a")
                try await audioMerger.merge(
                    systemAudioURL: systemURL,
                    micAudioURL: micURL,
                    outputURL: mergedURL
                )
                transcriptionURL = mergedURL
                needsAttribution = true
                print("[Scribe Debug] Merged audio to: \(mergedURL.path)")
            } else if let micURL = micM4AURL {
                // Only mic
                transcriptionURL = micURL
            } else if let systemURL = sysURL {
                // Only system
                transcriptionURL = systemURL
            } else {
                state = .error(message: "No valid audio to transcribe")
                return
            }

            // Transcribe the (merged) audio file once - full quality
            state = .processing(progress: 0.20, status: "Transcribing audio...")
            var transcription = try await transcriptionService.transcribe(
                audioURL: transcriptionURL,
                apiKey: apiKey,
                source: nil, // Don't set source yet - we'll attribute later
                progressHandler: { [weak self] progress, status in
                    Task { @MainActor in
                        let scaledProgress = 0.20 + (progress * 0.60)
                        self?.state = .processing(progress: scaledProgress, status: status)
                    }
                }
            )
            print("[Scribe Debug] Transcription complete: \(transcription.segments.count) segments")

            // Attribute segments to sources if we have both
            if needsAttribution, let micURL = micM4AURL, let systemURL = sysURL {
                state = .processing(progress: 0.85, status: "Analyzing audio sources...")

                // Analyze energy levels in both original files
                let micEnergy = try await sourceAttributor.analyzeEnergyLevels(url: micURL)
                let sysEnergy = try await sourceAttributor.analyzeEnergyLevels(url: systemURL)

                print("[Scribe Debug] Mic energy samples: \(micEnergy.count)")
                print("[Scribe Debug] System energy samples: \(sysEnergy.count)")

                // Attribute each segment based on which source had more energy
                let attributedSegments = sourceAttributor.attributeSegments(
                    segments: transcription.segments,
                    micEnergyLevels: micEnergy,
                    systemEnergyLevels: sysEnergy,
                    micSpeakerName: micSpeakerName
                )

                transcription = TranscriptionResult(
                    text: transcription.text,
                    segments: attributedSegments,
                    language: transcription.language
                )
            } else if micM4AURL != nil {
                // Only mic - label all as mic speaker
                let labeledSegments = transcription.segments.map { segment in
                    TranscriptionSegment(
                        id: segment.id,
                        start: segment.start,
                        end: segment.end,
                        text: segment.text,
                        speaker: micSpeakerName
                    )
                }
                transcription = TranscriptionResult(
                    text: transcription.text,
                    segments: labeledSegments,
                    language: transcription.language
                )
            } else {
                // Only system - label all as Speaker
                let labeledSegments = transcription.segments.map { segment in
                    TranscriptionSegment(
                        id: segment.id,
                        start: segment.start,
                        end: segment.end,
                        text: segment.text,
                        speaker: "Speaker"
                    )
                }
                transcription = TranscriptionResult(
                    text: transcription.text,
                    segments: labeledSegments,
                    language: transcription.language
                )
            }

            state = .processing(progress: 0.92, status: "Formatting...")

            let markdown = markdownFormatter.format(transcription, meetingTitle: meetingTitle.isEmpty ? nil : meetingTitle)
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
            if let micM4A = micM4AURL, micM4A != result.micAudioURL {
                try? FileManager.default.removeItem(at: micM4A)
            }
            if let sysURL = result.systemAudioURL {
                try? FileManager.default.removeItem(at: sysURL)
            }
            if transcriptionURL != micM4AURL && transcriptionURL != sysURL {
                try? FileManager.default.removeItem(at: transcriptionURL)
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
