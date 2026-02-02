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

        var speakerNames: [String: String] = [:]
        var speakerCount = 0

        for segment in result.segments {
            let speakerLabel: String

            if let speaker = segment.speaker {
                if let existingName = speakerNames[speaker] {
                    speakerLabel = existingName
                } else {
                    speakerCount += 1
                    let name = "Speaker \(speakerCount)"
                    speakerNames[speaker] = name
                    speakerLabel = name
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
