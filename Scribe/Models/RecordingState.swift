import Foundation

enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case processing(progress: Double, status: String)
    case renamingSpeakers(transcription: TranscriptionResult)
    case complete(transcriptURL: URL)
    case error(message: String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
}
