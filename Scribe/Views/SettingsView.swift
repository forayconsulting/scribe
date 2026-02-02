import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("micSpeakerName") private var micSpeakerName: String = "Me"
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var statusMessage: String?
    @State private var isError: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    if showKey {
                        TextField("OpenAI API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("OpenAI API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        if let pasteboardString = NSPasteboard.general.string(forType: .string) {
                            apiKey = pasteboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .help("Paste from clipboard")

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help("Show/hide key")
                }

                Text("Your API key is stored securely in the macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("OpenAI API Key")
            }

            Section {
                HStack {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || isSaving)

                    Button("Delete Key") {
                        deleteAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSaving)

                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let message = statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(isError ? .red : .green)
                }
            }

            Section {
                TextField("Your Name", text: $micSpeakerName)
                    .textFieldStyle(.roundedBorder)

                Text("Your speech from the microphone will be labeled with this name in transcripts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Speaker Identity")
            }

            Section {
                Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
            } header: {
                Text("Help")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 360)
        .task {
            await loadAPIKey()
        }
    }

    private func loadAPIKey() async {
        do {
            if let key = try await KeychainService.shared.getAPIKey() {
                apiKey = key
            }
        } catch {
            statusMessage = "Failed to load API key"
            isError = true
        }
    }

    private func saveAPIKey() {
        isSaving = true
        statusMessage = nil

        Task {
            do {
                try await KeychainService.shared.saveAPIKey(apiKey)
                statusMessage = "API key saved successfully"
                isError = false
            } catch {
                statusMessage = "Failed to save: \(error.localizedDescription)"
                isError = true
            }
            isSaving = false
        }
    }

    private func deleteAPIKey() {
        isSaving = true
        statusMessage = nil

        Task {
            do {
                try await KeychainService.shared.deleteAPIKey()
                apiKey = ""
                statusMessage = "API key deleted"
                isError = false
            } catch {
                statusMessage = "Failed to delete: \(error.localizedDescription)"
                isError = true
            }
            isSaving = false
        }
    }
}
