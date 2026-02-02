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

        // Collapse consecutive segments from the same speaker into turns
        let turns = collapseIntoTurns(segments: result.segments)

        // Map API speaker IDs to friendly names
        var speakerIdToName: [String: String] = [:]
        var speakerCount = 0

        for turn in turns {
            let speakerLabel: String

            if let speaker = turn.speaker {
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

            output += "\(turn.formattedTimestamp) **\(speakerLabel):** \(turn.text)\n\n"
        }

        output += "---\n\n"
        output += "*Transcribed with Scribe*\n"

        return output
    }

    /// Collapse consecutive segments from the same speaker into single turns
    private func collapseIntoTurns(segments: [TranscriptionSegment]) -> [Turn] {
        guard !segments.isEmpty else { return [] }

        var turns: [Turn] = []
        var currentTurn = Turn(
            start: segments[0].start,
            speaker: segments[0].speaker,
            texts: [segments[0].text]
        )

        for i in 1..<segments.count {
            let segment = segments[i]

            if segment.speaker == currentTurn.speaker {
                // Same speaker - append to current turn
                currentTurn.texts.append(segment.text)
            } else {
                // Different speaker - save current turn and start new one
                turns.append(currentTurn)
                currentTurn = Turn(
                    start: segment.start,
                    speaker: segment.speaker,
                    texts: [segment.text]
                )
            }
        }

        // Don't forget the last turn
        turns.append(currentTurn)

        return turns
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

/// A turn represents one speaker's continuous speech (collapsed from multiple segments)
private struct Turn {
    let start: Double
    let speaker: String?
    var texts: [String]

    var text: String {
        texts.joined(separator: " ")
    }

    var formattedTimestamp: String {
        let hours = Int(start) / 3600
        let minutes = (Int(start) % 3600) / 60
        let seconds = Int(start) % 60
        return String(format: "[%02d:%02d:%02d]", hours, minutes, seconds)
    }
}
