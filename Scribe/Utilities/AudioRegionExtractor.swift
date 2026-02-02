import AVFoundation

/// Extracts specific time regions from an audio file
struct AudioRegionExtractor {

    /// Extract a specific time region from an audio file
    /// Returns a new audio file URL containing just that region
    func extractRegion(from sourceURL: URL, region: AudioRegion, outputURL: URL) async throws -> URL {
        let asset = AVAsset(url: sourceURL)

        // Load duration to validate
        let duration = try await asset.load(.duration)
        let totalDuration = CMTimeGetSeconds(duration)

        // Clamp region to file bounds
        let startTime = max(0, region.start)
        let endTime = min(totalDuration, region.end)

        guard endTime > startTime else {
            throw AudioExtractorError.invalidRegion
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioExtractorError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Set time range
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 1000)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 1000)
        exportSession.timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Export
        await exportSession.export()

        if let error = exportSession.error {
            throw AudioExtractorError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw AudioExtractorError.exportIncomplete(exportSession.status)
        }

        return outputURL
    }

    /// Extract multiple regions and concatenate them into a single file
    /// Returns the concatenated file and a mapping of original timestamps
    func extractAndConcatenateRegions(
        from sourceURL: URL,
        regions: [AudioRegion],
        outputURL: URL
    ) async throws -> (url: URL, regionOffsets: [Double]) {
        guard !regions.isEmpty else {
            throw AudioExtractorError.noRegions
        }

        // If only one region, just extract it directly
        if regions.count == 1 {
            let url = try await extractRegion(from: sourceURL, region: regions[0], outputURL: outputURL)
            return (url, [regions[0].start])
        }

        // For multiple regions, we need to extract each and concatenate
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioExtractorError.trackCreationFailed
        }

        let asset = AVAsset(url: sourceURL)
        let assetTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let sourceTrack = assetTracks.first else {
            throw AudioExtractorError.noAudioTrack
        }

        var currentTime = CMTime.zero
        var regionOffsets: [Double] = []

        for region in regions {
            let startCMTime = CMTime(seconds: region.start, preferredTimescale: 1000)
            let endCMTime = CMTime(seconds: region.end, preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

            // Record the original start time for this region
            regionOffsets.append(region.start)

            try audioTrack.insertTimeRange(timeRange, of: sourceTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, CMTimeSubtract(endCMTime, startCMTime))
        }

        // Export the composition
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractorError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        try? FileManager.default.removeItem(at: outputURL)

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioExtractorError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw AudioExtractorError.exportIncomplete(exportSession.status)
        }

        return (outputURL, regionOffsets)
    }
}

enum AudioExtractorError: LocalizedError {
    case invalidRegion
    case exportSessionCreationFailed
    case exportFailed(Error)
    case exportIncomplete(AVAssetExportSession.Status)
    case noRegions
    case trackCreationFailed
    case noAudioTrack

    var errorDescription: String? {
        switch self {
        case .invalidRegion:
            return "Invalid audio region"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .exportIncomplete(let status):
            return "Export incomplete with status: \(status.rawValue)"
        case .noRegions:
            return "No regions to extract"
        case .trackCreationFailed:
            return "Failed to create audio track"
        case .noAudioTrack:
            return "No audio track found in source file"
        }
    }
}
