import AVFoundation
import Foundation

struct TranscriptionMerger {
    func merge(
        micResult: TranscriptionResult?,
        systemResult: TranscriptionResult?,
        micFileDuration: Double? = nil,
        systemFileDuration: Double? = nil
    ) -> TranscriptionResult? {
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
        var systemSegments = systemResult!.segments

        // For multi-turn conversations: distribute system segments into mic gaps
        if !micSegments.isEmpty && !systemSegments.isEmpty {
            systemSegments = alignSystemSegmentsToMicGaps(
                micSegments: micSegments,
                systemSegments: systemSegments,
                micDuration: micFileDuration
            )
        }

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

    /// Align system segments to fit into gaps in mic segments
    /// This handles multi-turn conversations where user talks, then system plays, then user talks, etc.
    private func alignSystemSegmentsToMicGaps(
        micSegments: [TranscriptionSegment],
        systemSegments: [TranscriptionSegment],
        micDuration: Double?
    ) -> [TranscriptionSegment] {
        // Find all gaps in mic segments (periods of silence = system audio playing)
        var gaps: [(start: Double, end: Double)] = []

        // Gap before first mic segment (if significant)
        if let firstMic = micSegments.first, firstMic.start > 1.0 {
            gaps.append((0, firstMic.start))
        }

        // Gaps between mic segments
        for i in 0..<(micSegments.count - 1) {
            let currentEnd = micSegments[i].end
            let nextStart = micSegments[i + 1].start
            let gapDuration = nextStart - currentEnd

            // Only consider gaps > 1 second as meaningful
            if gapDuration > 1.0 {
                gaps.append((currentEnd, nextStart))
            }
        }

        // Gap after last mic segment
        if let duration = micDuration, let lastMic = micSegments.last {
            let trailingGap = duration - lastMic.end
            if trailingGap > 1.0 {
                gaps.append((lastMic.end, duration))
            }
        }

        print("[Scribe Debug] Found \(gaps.count) gaps in mic segments:")
        for (i, gap) in gaps.enumerated() {
            print("[Scribe Debug]   Gap \(i): \(gap.start)s to \(gap.end)s (duration: \(gap.end - gap.start)s)")
        }

        // If no gaps found, use simple offset approach
        guard !gaps.isEmpty else {
            print("[Scribe Debug] No gaps found, returning system segments as-is")
            return systemSegments
        }

        // Group consecutive system segments into "blocks" that likely belong together
        let systemBlocks = groupIntoBlocks(segments: systemSegments, maxGap: 2.0)
        print("[Scribe Debug] Grouped system segments into \(systemBlocks.count) blocks")

        // Distribute system blocks into gaps
        var alignedSegments: [TranscriptionSegment] = []
        var gapIndex = 0

        for block in systemBlocks {
            guard gapIndex < gaps.count else {
                // No more gaps - append remaining blocks with last offset
                let lastGapStart = gaps.last?.start ?? 0
                let blockStart = block.first?.start ?? 0
                let offset = lastGapStart - blockStart
                alignedSegments.append(contentsOf: offsetSegments(block, by: offset))
                continue
            }

            let gap = gaps[gapIndex]
            let blockStart = block.first?.start ?? 0
            let offset = gap.start - blockStart

            print("[Scribe Debug] Placing block (starting at \(blockStart)s) into gap \(gapIndex) with offset \(offset)s")

            alignedSegments.append(contentsOf: offsetSegments(block, by: offset))
            gapIndex += 1
        }

        return alignedSegments
    }

    /// Group segments into blocks based on gaps between them
    private func groupIntoBlocks(segments: [TranscriptionSegment], maxGap: Double) -> [[TranscriptionSegment]] {
        guard !segments.isEmpty else { return [] }

        var blocks: [[TranscriptionSegment]] = []
        var currentBlock: [TranscriptionSegment] = [segments[0]]

        for i in 1..<segments.count {
            let prevEnd = segments[i - 1].end
            let currStart = segments[i].start

            if currStart - prevEnd > maxGap {
                // Start a new block
                blocks.append(currentBlock)
                currentBlock = [segments[i]]
            } else {
                currentBlock.append(segments[i])
            }
        }

        blocks.append(currentBlock)
        return blocks
    }

    /// Apply an offset to all segments
    private func offsetSegments(_ segments: [TranscriptionSegment], by offset: Double) -> [TranscriptionSegment] {
        return segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                start: max(0, segment.start + offset),
                end: max(0, segment.end + offset),
                text: segment.text,
                speaker: segment.speaker
            )
        }
    }

    /// Get the duration of an audio file in seconds
    static func getAudioDuration(url: URL) async -> Double? {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            print("[Scribe Debug] Failed to get duration for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
