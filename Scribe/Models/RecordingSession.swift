import Foundation

struct RecordingSession: Identifiable, Hashable, Codable {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}
