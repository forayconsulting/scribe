import AVFoundation
import Accelerate

/// Represents a region of detected speech/audio in a file
struct AudioRegion {
    let start: Double  // seconds from file start
    let end: Double    // seconds from file start

    var duration: Double { end - start }
}

/// Detects regions of speech/audio in an audio file based on energy levels
struct SpeechRegionDetector {
    /// Minimum region duration in seconds (ignore very short sounds)
    private let minRegionDuration: Double = 0.3

    /// Silence threshold in dB (audio below this is considered silence)
    private let silenceThresholdDb: Float = -35.0

    /// Window size for analysis in seconds
    private let windowSize: Double = 0.05

    /// Minimum gap to merge adjacent regions
    private let mergeGap: Double = 0.5

    /// Detect regions of audio/speech in the given file
    func detectRegions(in url: URL) async throws -> [AudioRegion] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SpeechDetectorError.bufferCreationFailed
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw SpeechDetectorError.noAudioData
        }

        let channelCount = Int(format.channelCount)
        let samples = Int(buffer.frameLength)

        // Mix down to mono by averaging channels
        var monoSamples = [Float](repeating: 0, count: samples)
        for i in 0..<samples {
            var sum: Float = 0
            for ch in 0..<channelCount {
                sum += channelData[ch][i]
            }
            monoSamples[i] = sum / Float(channelCount)
        }

        // Calculate RMS energy for each window
        let windowSamples = Int(windowSize * sampleRate)
        let hopSamples = windowSamples / 2  // 50% overlap
        var energyLevels: [(time: Double, db: Float)] = []

        var position = 0
        while position + windowSamples <= samples {
            let windowStart = position
            let windowEnd = position + windowSamples

            // Calculate RMS
            var sumSquares: Float = 0
            for i in windowStart..<windowEnd {
                sumSquares += monoSamples[i] * monoSamples[i]
            }
            let rms = sqrt(sumSquares / Float(windowSamples))

            // Convert to dB
            let db = rms > 0 ? 20 * log10(rms) : -100

            let time = Double(position) / sampleRate
            energyLevels.append((time, db))

            position += hopSamples
        }

        // Find regions above threshold
        var regions: [AudioRegion] = []
        var regionStart: Double? = nil

        for (time, db) in energyLevels {
            if db > silenceThresholdDb {
                if regionStart == nil {
                    regionStart = time
                }
            } else {
                if let start = regionStart {
                    let end = time
                    if end - start >= minRegionDuration {
                        regions.append(AudioRegion(start: start, end: end))
                    }
                    regionStart = nil
                }
            }
        }

        // Close any open region
        if let start = regionStart {
            let end = Double(samples) / sampleRate
            if end - start >= minRegionDuration {
                regions.append(AudioRegion(start: start, end: end))
            }
        }

        // Merge regions that are close together
        let mergedRegions = mergeCloseRegions(regions)

        print("[Scribe Debug] Detected \(mergedRegions.count) audio regions in \(url.lastPathComponent)")
        for (i, region) in mergedRegions.enumerated() {
            print("[Scribe Debug]   Region \(i): \(String(format: "%.1f", region.start))s - \(String(format: "%.1f", region.end))s (duration: \(String(format: "%.1f", region.duration))s)")
        }

        return mergedRegions
    }

    private func mergeCloseRegions(_ regions: [AudioRegion]) -> [AudioRegion] {
        guard !regions.isEmpty else { return [] }

        var merged: [AudioRegion] = []
        var current = regions[0]

        for i in 1..<regions.count {
            let next = regions[i]

            if next.start - current.end <= mergeGap {
                // Merge with current
                current = AudioRegion(start: current.start, end: next.end)
            } else {
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }
}

enum SpeechDetectorError: LocalizedError {
    case bufferCreationFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noAudioData:
            return "No audio data found in file"
        }
    }
}
