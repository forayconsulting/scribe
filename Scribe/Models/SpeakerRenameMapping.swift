import Foundation

struct SpeakerRenameMapping: Identifiable {
    let id = UUID()
    let originalName: String
    var newName: String
    let segmentCount: Int
    let isUserMic: Bool
    let sampleText: String

    init(originalName: String, segmentCount: Int, isUserMic: Bool, sampleText: String) {
        self.originalName = originalName
        self.newName = originalName
        self.segmentCount = segmentCount
        self.isUserMic = isUserMic
        self.sampleText = sampleText
    }
}
