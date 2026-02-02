import AVFoundation
import Foundation

struct AudioMerger {
    /// Merges two audio files into a single M4A output.
    /// Both audio tracks are mixed together (not concatenated).
    func merge(systemAudioURL: URL, micAudioURL: URL, outputURL: URL) async throws {
        let composition = AVMutableComposition()

        // Load both audio assets
        let systemAsset = AVURLAsset(url: systemAudioURL)
        let micAsset = AVURLAsset(url: micAudioURL)

        // Load tracks
        let systemTracks = try await systemAsset.loadTracks(withMediaType: .audio)
        let micTracks = try await micAsset.loadTracks(withMediaType: .audio)

        guard let systemTrack = systemTracks.first else {
            throw AudioMergerError.noSystemAudioTrack
        }

        // Get durations
        let systemDuration = try await systemAsset.load(.duration)
        let micDuration = try await micAsset.load(.duration)

        // Add system audio track
        guard let systemCompositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioMergerError.failedToCreateTrack
        }

        try systemCompositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: systemDuration),
            of: systemTrack,
            at: .zero
        )

        // Add mic audio track if available
        if let micTrack = micTracks.first {
            guard let micCompositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AudioMergerError.failedToCreateTrack
            }

            try micCompositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: micDuration),
                of: micTrack,
                at: .zero
            )
        }

        // Create audio mix to balance volumes
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []

        // System audio at full volume
        let systemParams = AVMutableAudioMixInputParameters(track: systemCompositionTrack)
        systemParams.setVolume(1.0, at: .zero)
        inputParameters.append(systemParams)

        audioMix.inputParameters = inputParameters

        // Export
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioMergerError.failedToCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix

        await exportSession.export()

        if let error = exportSession.error {
            throw AudioMergerError.exportFailed(error)
        }

        guard exportSession.status == .completed else {
            throw AudioMergerError.exportIncomplete(exportSession.status)
        }
    }
}

enum AudioMergerError: LocalizedError {
    case noSystemAudioTrack
    case noMicAudioTrack
    case failedToCreateTrack
    case failedToCreateExportSession
    case exportFailed(Error)
    case exportIncomplete(AVAssetExportSession.Status)

    var errorDescription: String? {
        switch self {
        case .noSystemAudioTrack:
            return "No audio track found in system audio file"
        case .noMicAudioTrack:
            return "No audio track found in microphone file"
        case .failedToCreateTrack:
            return "Failed to create composition track"
        case .failedToCreateExportSession:
            return "Failed to create export session"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .exportIncomplete(let status):
            return "Export incomplete with status: \(status.rawValue)"
        }
    }
}
