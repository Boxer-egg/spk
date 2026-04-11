import Foundation

class LLMManager {
    static let shared = LLMManager()
    
    func refineText(systemPrompt: String, userText: String, completion: @escaping (Result<String, Error>) -> Void) {
        let settings = SettingsManager.shared
        guard settings.isLLMEnabled, !settings.apiKey.isEmpty else {
            completion(.success(userText))
            return
        }

        let urlString = settings.apiBaseURL + "/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LLMManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API Base URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(.failure(NSError(domain: "LLMManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from LLM API"])))
                return
            }

            completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        task.resume()
    }

    func testConnection(completion: @escaping (Result<String, Error>) -> Void) {
        refineText(systemPrompt: "You are a helpful assistant.", userText: "Hello, this is a test connection.") { result in
            switch result {
            case .success:
                completion(.success("Connection Successful!"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
