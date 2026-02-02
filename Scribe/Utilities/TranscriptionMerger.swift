import Foundation

struct TranscriptionMerger {
    func merge(micResult: TranscriptionResult?, systemResult: TranscriptionResult?) -> TranscriptionResult? {
        // Handle edge cases where one or both sources are missing
        guard micResult != nil || systemResult != nil else {
            return nil
        }

        if micResult == nil {
            return systemResult
        }

        if systemResult == nil {
            return micResult
        }

        // Both results exist - merge them
        let micSegments = micResult!.segments
        let systemSegments = systemResult!.segments

        // Combine all segments
        var allSegments = micSegments + systemSegments

        // Sort by start timestamp
        allSegments.sort { $0.start < $1.start }

        // Re-assign sequential IDs
        let reindexedSegments = allSegments.enumerated().map { index, segment in
            TranscriptionSegment(
                id: index,
                start: segment.start,
                end: segment.end,
                text: segment.text,
                speaker: segment.speaker
            )
        }

        // Combine text in chronological order
        let combinedText = reindexedSegments.map { $0.text }.joined(separator: " ")

        // Use language from whichever result has it
        let language = micResult?.language ?? systemResult?.language

        return TranscriptionResult(
            text: combinedText,
            segments: reindexedSegments,
            language: language
        )
    }
}
