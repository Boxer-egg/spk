import Foundation
import AVFoundation

class WhisperProvider: SpeechRecognitionProvider {
    weak var delegate: SpeechRecognitionProviderDelegate?
    private var uploadTask: URLSessionDataTask?

    func start(audioEngine: AVAudioEngine) throws {
        guard !SettingsManager.shared.whisperApiKey.isEmpty else {
            throw WhisperError.missingCredentials
        }
    }

    func stop() {
        uploadTask?.cancel()

        guard let audioURL = AudioRecorderManager.shared.stopRecording(identifier: "whisper") else {
            delegate?.provider(self, didFailWithError: WhisperError.noAudioData)
            return
        }

        uploadAudioFile(audioURL) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let text):
                self.delegate?.provider(self, didFinishWithText: text)
            case .failure(let error):
                self.delegate?.provider(self, didFailWithError: error)
            }
        }
    }

    private func uploadAudioFile(_ url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = SettingsManager.shared.whisperApiKey
        let endpoint = "https://api.openai.com/v1/audio/transcriptions"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        if let fileData = try? Data(contentsOf: url) {
            body.append(fileData)
        }
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        uploadTask = URLSession.shared.dataTask(with: request) { data, response, error in
            // Clean up the temporary audio file regardless of success or failure
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                completion(.failure(WhisperError.invalidResponse))
                return
            }
            completion(.success(text))
        }
        uploadTask?.resume()
    }
}

enum WhisperError: Error {
    case missingCredentials
    case noAudioData
    case invalidResponse
}
