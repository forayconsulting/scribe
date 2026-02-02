import AVFoundation
import Accelerate

/// Determines which audio source (mic or system) a segment came from
/// by analyzing energy levels at the segment's timestamp
struct AudioSourceAttributor {

    /// Analyze audio files and return energy levels at regular intervals
    func analyzeEnergyLevels(url: URL, windowSize: Double = 0.1) async throws -> [(time: Double, energy: Float)] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AttributorError.bufferCreationFailed
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw AttributorError.noAudioData
        }

        let channelCount = Int(format.channelCount)
        let samples = Int(buffer.frameLength)

        // Mix down to mono
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
        var energyLevels: [(time: Double, energy: Float)] = []

        var position = 0
        while position + windowSamples <= samples {
            var sumSquares: Float = 0
            for i in position..<(position + windowSamples) {
                sumSquares += monoSamples[i] * monoSamples[i]
            }
            let rms = sqrt(sumSquares / Float(windowSamples))
            let time = Double(position) / sampleRate
            energyLevels.append((time, rms))
            position += windowSamples
        }

        return energyLevels
    }

    /// Get the average energy for a time range
    func getAverageEnergy(
        energyLevels: [(time: Double, energy: Float)],
        startTime: Double,
        endTime: Double
    ) -> Float {
        let relevantLevels = energyLevels.filter { $0.time >= startTime && $0.time < endTime }
        guard !relevantLevels.isEmpty else { return 0 }

        let totalEnergy = relevantLevels.reduce(Float(0)) { $0 + $1.energy }
        return totalEnergy / Float(relevantLevels.count)
    }

    /// Attribute segments to sources based on energy comparison
    func attributeSegments(
        segments: [TranscriptionSegment],
        micEnergyLevels: [(time: Double, energy: Float)],
        systemEnergyLevels: [(time: Double, energy: Float)],
        micSpeakerName: String
    ) -> [TranscriptionSegment] {
        return segments.map { segment in
            let micEnergy = getAverageEnergy(
                energyLevels: micEnergyLevels,
                startTime: segment.start,
                endTime: segment.end
            )
            let sysEnergy = getAverageEnergy(
                energyLevels: systemEnergyLevels,
                startTime: segment.start,
                endTime: segment.end
            )

            // Attribute to whichever source has higher energy
            // Use a ratio threshold to handle cases where both have some energy
            let speaker: String
            if micEnergy > sysEnergy * 1.5 {
                speaker = micSpeakerName
            } else if sysEnergy > micEnergy * 1.5 {
                speaker = "Speaker"
            } else if micEnergy > sysEnergy {
                speaker = micSpeakerName
            } else {
                speaker = "Speaker"
            }

            return TranscriptionSegment(
                id: segment.id,
                start: segment.start,
                end: segment.end,
                text: segment.text,
                speaker: speaker
            )
        }
    }
}

enum AttributorError: LocalizedError {
    case bufferCreationFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noAudioData:
            return "No audio data found"
        }
    }
}
