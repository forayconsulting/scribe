import Foundation

enum AudioSource {
    case microphone(speakerName: String)
    case systemAudio
}

actor TranscriptionService {
    private let apiEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let maxFileSize: Int64 = 25 * 1024 * 1024

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for the request
        config.timeoutIntervalForResource = 600 // 10 minutes total
        return URLSession(configuration: config)
    }()

    func transcribe(audioURL: URL, apiKey: String, source: AudioSource? = nil, progressHandler: @escaping @Sendable (Double, String) -> Void) async throws -> TranscriptionResult {
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0

        var result: TranscriptionResult
        if fileSize > maxFileSize {
            result = try await transcribeChunked(audioURL: audioURL, apiKey: apiKey, progressHandler: progressHandler)
        } else {
            progressHandler(0.1, "Uploading audio...")
            result = try await uploadAndTranscribe(audioURL: audioURL, apiKey: apiKey)
            progressHandler(1.0, "Complete")
        }

        // Override speaker labels for microphone source
        if case .microphone(let speakerName) = source {
            result = TranscriptionResult(
                text: result.text,
                segments: result.segments.map { segment in
                    TranscriptionSegment(
                        id: segment.id,
                        start: segment.start,
                        end: segment.end,
                        text: segment.text,
                        speaker: speakerName
                    )
                },
                language: result.language
            )
        }

        return result
    }

    private func uploadAndTranscribe(audioURL: URL, apiKey: String) async throws -> TranscriptionResult {
        let boundary = UUID().uuidString
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("gpt-4o-transcribe-diarize\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("diarized_json\r\n".data(using: .utf8)!)

        // Required for diarization model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chunking_strategy\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw TranscriptionError.apiError(errorJson.error.message)
            }
            throw TranscriptionError.httpError(httpResponse.statusCode)
        }

        // Debug: log raw response if decode fails
        do {
            let apiResponse = try JSONDecoder().decode(TranscriptionResult.APIResponse.self, from: data)
            return TranscriptionResult(from: apiResponse)
        } catch {
            // Write raw response to Desktop for debugging
            let debugFile = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/scribe_api_response.json")
            try? data.write(to: debugFile)
            throw error
        }
    }

    private func transcribeChunked(audioURL: URL, apiKey: String, progressHandler: @escaping @Sendable (Double, String) -> Void) async throws -> TranscriptionResult {
        let chunker = AudioChunker()
        let chunks = try await chunker.splitAudio(at: audioURL, maxSizeBytes: maxFileSize)

        var allSegments: [TranscriptionSegment] = []
        var fullText = ""
        var language: String?
        var timeOffset: Double = 0

        for (index, chunkURL) in chunks.enumerated() {
            let progress = Double(index) / Double(chunks.count)
            progressHandler(progress, "Transcribing chunk \(index + 1) of \(chunks.count)...")

            let result = try await uploadAndTranscribe(audioURL: chunkURL, apiKey: apiKey)

            if language == nil {
                language = result.language
            }

            let adjustedSegments = result.segments.map { segment in
                TranscriptionSegment(
                    id: allSegments.count + segment.id,
                    start: segment.start + timeOffset,
                    end: segment.end + timeOffset,
                    text: segment.text,
                    speaker: segment.speaker
                )
            }

            allSegments.append(contentsOf: adjustedSegments)

            if !fullText.isEmpty {
                fullText += " "
            }
            fullText += result.text

            if let lastSegment = adjustedSegments.last {
                timeOffset = lastSegment.end
            }

            try? FileManager.default.removeItem(at: chunkURL)
        }

        progressHandler(1.0, "Complete")

        return TranscriptionResult(text: fullText, segments: allSegments, language: language)
    }
}

private struct APIErrorResponse: Codable {
    let error: APIError

    struct APIError: Codable {
        let message: String
        let type: String?
    }
}

enum TranscriptionError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        }
    }
}
