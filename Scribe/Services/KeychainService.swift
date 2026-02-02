import Foundation

// Using UserDefaults for development (simpler, no keychain prompts)
// For production, switch back to Keychain for security
actor KeychainService {
    static let shared = KeychainService()

    private let apiKeyKey = "com.scribe.app.openai-api-key"

    private init() {}

    func saveAPIKey(_ key: String) throws {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
    }

    func getAPIKey() throws -> String? {
        UserDefaults.standard.string(forKey: apiKeyKey)
    }

    func deleteAPIKey() throws {
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
    }
}

enum KeychainError: LocalizedError {
    case unableToSave(OSStatus)
    case unableToRead(OSStatus)
    case unableToDelete(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Unable to save: \(status)"
        case .unableToRead(let status):
            return "Unable to read: \(status)"
        case .unableToDelete(let status):
            return "Unable to delete: \(status)"
        case .invalidData:
            return "Invalid data"
        }
    }
}
