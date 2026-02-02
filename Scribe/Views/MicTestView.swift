import SwiftUI

/// Isolated test view for microphone capture only.
/// Use this to verify mic capture works independently before integrating.
struct MicTestView: View {
    @State private var isRecording = false
    @State private var statusMessage = "Ready to test microphone"
    @State private var recordedFileURL: URL?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingStartTime: Date?

    private let micService = MicrophoneCaptureService()

    var body: some View {
        VStack(spacing: 24) {
            Text("Microphone Test")
                .font(.title2)
                .fontWeight(.semibold)

            if isRecording {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(formattedDuration)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 70, height: 70)

                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            if let url = recordedFileURL {
                VStack(spacing: 8) {
                    Text("Recorded: \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Play in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.bordered)

                        Button("Play with QuickTime") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 400, height: 350)
    }

    private var formattedDuration: String {
        let duration: TimeInterval
        if let start = recordingStartTime {
            duration = Date().timeIntervalSince(start)
        } else {
            duration = 0
        }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            // Check permission
            if !MicrophoneCaptureService.hasPermission() {
                let granted = await MicrophoneCaptureService.requestPermission()
                if !granted {
                    await MainActor.run {
                        statusMessage = "Microphone permission denied. Please grant access in System Settings."
                    }
                    return
                }
            }

            // Create output URL - using .caf format for maximum compatibility
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("mic_test_\(UUID().uuidString)")
                .appendingPathExtension("caf")

            do {
                try await micService.startCapturing(outputURL: outputURL)

                await MainActor.run {
                    isRecording = true
                    recordingStartTime = Date()
                    recordedFileURL = nil
                    statusMessage = "Recording microphone... Speak now!"
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed to start: \(error.localizedDescription)"
                }
            }
        }
    }

    private func stopRecording() {
        Task {
            let url = await micService.stopCapturing()

            await MainActor.run {
                isRecording = false
                recordingStartTime = nil

                if let url = url {
                    // Check file size
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attrs?[.size] as? Int64 ?? 0

                    if size > 0 {
                        recordedFileURL = url
                        statusMessage = "Recording saved! File size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
                    } else {
                        statusMessage = "Warning: File is empty (0 bytes)"
                    }
                } else {
                    statusMessage = "No file was created"
                }
            }
        }
    }
}
