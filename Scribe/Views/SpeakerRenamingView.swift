import SwiftUI

struct SpeakerRenamingView: View {
    let transcription: TranscriptionResult
    let onApply: ([String: String]) -> Void
    let onSkip: () -> Void

    @State private var mappings: [SpeakerRenameMapping] = []

    var body: some View {
        VStack(spacing: 16) {
            headerSection

            Divider()

            speakerList

            Divider()

            buttonSection
        }
        .padding()
        .onAppear {
            buildMappings()
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                Text("Rename Speakers")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("Edit speaker names before saving")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var speakerList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach($mappings) { $mapping in
                    speakerRow(mapping: $mapping)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    @ViewBuilder
    private func speakerRow(mapping: Binding<SpeakerRenameMapping>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: mapping.wrappedValue.isUserMic ? "mic.fill" : "person.fill")
                    .foregroundColor(mapping.wrappedValue.isUserMic ? .green : .blue)
                    .frame(width: 20)

                Text(mapping.wrappedValue.originalName)
                    .fontWeight(.medium)

                Text("(\(mapping.wrappedValue.segmentCount) segment\(mapping.wrappedValue.segmentCount == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Name", text: mapping.newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }

            Text("\"\(mapping.wrappedValue.sampleText)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.leading, 28)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("Skip") {
                onSkip()
            }
            .buttonStyle(.bordered)

            Button("Apply & Save") {
                let renames = Dictionary(
                    uniqueKeysWithValues: mappings.map { ($0.originalName, $0.newName) }
                )
                onApply(renames)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func buildMappings() {
        let micSpeakerName = UserDefaults.standard.string(forKey: "micSpeakerName") ?? "Me"

        var speakerData: [String: (count: Int, firstText: String)] = [:]

        for segment in transcription.segments {
            let speaker = segment.speaker ?? "Speaker"
            if speakerData[speaker] == nil {
                let truncated = String(segment.text.prefix(60))
                let sampleText = segment.text.count > 60 ? truncated + "..." : truncated
                speakerData[speaker] = (count: 1, firstText: sampleText)
            } else {
                speakerData[speaker]!.count += 1
            }
        }

        mappings = speakerData.map { speaker, data in
            SpeakerRenameMapping(
                originalName: speaker,
                segmentCount: data.count,
                isUserMic: speaker == micSpeakerName,
                sampleText: data.firstText
            )
        }
        .sorted { lhs, rhs in
            if lhs.isUserMic != rhs.isUserMic {
                return lhs.isUserMic
            }
            return lhs.originalName < rhs.originalName
        }
    }
}
