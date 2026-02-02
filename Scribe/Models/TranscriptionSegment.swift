import Foundation

struct TranscriptionSegment: Codable, Identifiable, Equatable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
    let speaker: String?

    var formattedTimestamp: String {
        formatTimestamp(start)
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "[%02d:%02d:%02d]", hours, minutes, secs)
    }
}
