import Foundation

struct MarkdownFormatter {
    func format(_ result: TranscriptionResult, meetingTitle: String? = nil) -> String {
        var output = ""

        let title = meetingTitle ?? "Meeting Transcript"
        output += "# \(title)\n\n"

        let date = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        output += "**Date:** \(formatter.string(from: date))\n\n"

        output += "---\n\n"
        output += "## Transcript\n\n"

        // Map API speaker IDs to friendly names, but preserve user-configured names
        var speakerIdToName: [String: String] = [:]
        var speakerCount = 0

        for segment in result.segments {
            let speakerLabel: String

            if let speaker = segment.speaker {
                // Check if this looks like an API-generated ID (e.g., "speaker_0", "SPEAKER_00")
                let isApiId = speaker.lowercased().hasPrefix("speaker_") ||
                              speaker.lowercased().hasPrefix("spk_")

                if isApiId {
                    // Map API IDs to friendly "Speaker N" format
                    if let existingName = speakerIdToName[speaker] {
                        speakerLabel = existingName
                    } else {
                        speakerCount += 1
                        let name = "Speaker \(speakerCount)"
                        speakerIdToName[speaker] = name
                        speakerLabel = name
                    }
                } else {
                    // Use the actual name directly (user-configured name)
                    speakerLabel = speaker
                }
            } else {
                speakerLabel = "Speaker"
            }

            output += "\(segment.formattedTimestamp) **\(speakerLabel):** \(segment.text)\n\n"
        }

        output += "---\n\n"
        output += "*Transcribed with Scribe*\n"

        return output
    }

    func suggestFilename(for title: String?) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        if let title = title, !title.isEmpty {
            let sanitized = title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .trimmingCharacters(in: .whitespaces)
            return "\(dateString) - \(sanitized).md"
        }

        return "\(dateString) - Meeting Transcript.md"
    }
}
