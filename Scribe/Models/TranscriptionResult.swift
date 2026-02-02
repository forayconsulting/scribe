import Foundation

struct TranscriptionResult: Codable {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?

    struct APIResponse: Codable {
        let text: String
        let segments: [APISegment]?
        let language: String?
        let words: [APIWord]?
    }

    struct APISegment: Codable {
        let id: Int
        let start: Double
        let end: Double
        let text: String
    }

    struct APIWord: Codable {
        let word: String
        let start: Double
        let end: Double
        let speaker: String?
    }

    init(from response: APIResponse) {
        self.text = response.text
        self.language = response.language

        if let apiSegments = response.segments {
            var speakerMap: [Int: String] = [:]

            if let words = response.words {
                for word in words where word.speaker != nil {
                    for (index, segment) in apiSegments.enumerated() {
                        if word.start >= segment.start && word.start < segment.end {
                            if speakerMap[index] == nil {
                                speakerMap[index] = word.speaker
                            }
                            break
                        }
                    }
                }
            }

            self.segments = apiSegments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: segment.id,
                    start: segment.start,
                    end: segment.end,
                    text: segment.text.trimmingCharacters(in: .whitespaces),
                    speaker: speakerMap[index]
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
