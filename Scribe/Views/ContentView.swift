import SwiftUI

struct ContentView: View {
    @State private var viewModel = RecordingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 400, minHeight: 350)
        .sheet(isPresented: $viewModel.showSettings) {
            settingsSheet
        }
        .onAppear {
            viewModel.checkPermissions()
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Scribe")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .idle:
            RecordingView(viewModel: viewModel)

        case .recording:
            RecordingView(viewModel: viewModel)

        case .processing(let progress, let status):
            ProcessingView(progress: progress, status: status)

        case .renamingSpeakers(let transcription):
            SpeakerRenamingView(
                transcription: transcription,
                onApply: { renames in
                    Task {
                        await viewModel.finalizeSpeakerRenaming(with: renames)
                    }
                },
                onSkip: {
                    Task {
                        await viewModel.skipSpeakerRenaming()
                    }
                }
            )

        case .complete(let transcriptURL):
            completeView(transcriptURL: transcriptURL)

        case .error(let message):
            errorView(message: message)
        }
    }

    @ViewBuilder
    private func completeView(transcriptURL: URL) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Transcription Complete!")
                .font(.headline)

            Text(transcriptURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Open Transcript") {
                    viewModel.openTranscript()
                }
                .buttonStyle(.borderedProminent)

                Button("New Recording") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Error")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private var settingsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    viewModel.showSettings = false
                    Task {
                        await viewModel.checkAPIKey()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            SettingsView()
        }
        .frame(width: 500, height: 350)
    }
}
