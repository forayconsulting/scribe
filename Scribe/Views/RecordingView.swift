import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel

    var body: some View {
        VStack(spacing: 24) {
            if !viewModel.hasPermission {
                PermissionBanner {
                    viewModel.requestPermission()
                }
            } else if !viewModel.hasAPIKey {
                APIKeyBanner {
                    viewModel.showSettings = true
                }
            } else {
                recordingContent
            }
        }
        .padding()
    }

    @ViewBuilder
    private var recordingContent: some View {
        VStack(spacing: 20) {
            if case .recording = viewModel.state {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(viewModel.formattedDuration)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.red)
                }

                Text("Recording...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                TextField("Meeting Title (optional)", text: $viewModel.meetingTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Text("Press to start recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            RecordButton(isRecording: viewModel.state.isRecording) {
                Task {
                    if viewModel.state.isRecording {
                        await viewModel.stopRecording()
                    } else {
                        await viewModel.startRecording()
                    }
                }
            }

            if case .recording = viewModel.state {
                Text("Click to stop and transcribe")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct APIKeyBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text("API Key Required")
                .font(.headline)

            Text("Please configure your OpenAI API key in settings to enable transcription.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}
