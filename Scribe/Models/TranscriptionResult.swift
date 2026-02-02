import Foundation

struct TranscriptionResult: Codable, Equatable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?

    /// Response format for diarized_json from gpt-4o-transcribe-diarize
    struct APIResponse: Codable {
        let text: String
        let segments: [APISegment]?
        let language: String?
    }

    /// Diarized segment with speaker label
    struct APISegment: Codable {
        let id: String?
        let start: Double
        let end: Double
        let text: String
        let speaker: String?
    }

    init(from response: APIResponse) {
        self.text = response.text
        self.language = response.language

        if let apiSegments = response.segments {
            self.segments = apiSegments.enumerated().map { index, segment in
                // Map speaker labels: "A" -> "Speaker A", "B" -> "Speaker B", etc.
                let speakerLabel: String?
                if let speaker = segment.speaker {
                    speakerLabel = "Speaker \(speaker)"
                } else {
                    speakerLabel = nil
                }

                return TranscriptionSegment(
                    id: index,
                    start: segment.start,
                    end: segment.end,
                    text: segment.text.trimmingCharacters(in: .whitespaces),
                    speaker: speakerLabel
                )
            }
        } else {
            self.segments = [
                TranscriptionSegment(
                    id: 0,
                    start: 0,
                    end: 0,
                    text: response.text,
                    speaker: nil
                )
            ]
        }
    }

    init(text: String, segments: [TranscriptionSegment], language: String?) {
        self.text = text
        self.segments = segments
        self.language = language
    }
}
