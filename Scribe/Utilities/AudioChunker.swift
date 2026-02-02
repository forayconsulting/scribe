import AVFoundation
import Foundation

struct AudioChunker {
    private let chunkDuration: TimeInterval = 1200

    func splitAudio(at url: URL, maxSizeBytes: Int64) async throws -> [URL] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        if fileSize <= maxSizeBytes {
            return [url]
        }

        let estimatedChunks = max(2, Int(ceil(Double(fileSize) / Double(maxSizeBytes))))
        let chunkSeconds = totalSeconds / Double(estimatedChunks)

        var chunks: [URL] = []
        var currentTime: TimeInterval = 0

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        while currentTime < totalSeconds {
            let endTime = min(currentTime + chunkSeconds, totalSeconds)
            let chunkURL = tempDir.appendingPathComponent("chunk_\(chunks.count).m4a")

            try await exportChunk(
                from: asset,
                startTime: currentTime,
                endTime: endTime,
                to: chunkURL
            )

            chunks.append(chunkURL)
            currentTime = endTime
        }

        return chunks
    }

    private func exportChunk(from asset: AVAsset, startTime: TimeInterval, endTime: TimeInterval, to outputURL: URL) async throws {
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 48000)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 48000)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioChunkerError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioChunkerError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw AudioChunkerError.exportIncomplete(exportSession.status)
        }
    }
}

enum AudioChunkerError: LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(Error)
    case exportIncomplete(AVAssetExportSession.Status)

    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .exportIncomplete(let status):
            return "Export incomplete with status: \(status.rawValue)"
        }
    }
}
