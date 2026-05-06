import Foundation
import AVFoundation

class TongyiProvider: SpeechRecognitionProvider {
    weak var delegate: SpeechRecognitionProviderDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var isRunning = false

    func start(audioEngine: AVAudioEngine) throws {
        let apiKey = SettingsManager.shared.tongyiApiKey

        guard !apiKey.isEmpty else {
            throw TongyiError.missingCredentials
        }

        let url = URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/realtime")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()

        let initMessage: [String: Any] = [
            "model": "qwen3-asr-flash-realtime",
            "language": SettingsManager.shared.selectedLanguage.rawValue
        ]
        if let data = try? JSONSerialization.data(withJSONObject: initMessage) {
            webSocketTask?.send(.data(data)) { _ in }
        }

        isRunning = true
        receiveMessages()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self, self.isRunning else { return }
            if let pcmData = self.convertToPCM16(buffer) {
                self.webSocketTask?.send(.data(pcmData)) { _ in }
            }
        }
    }

    func stop() {
        isRunning = false
        webSocketTask?.send(.string("{\"is_end\": true}")) { _ in }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessages()
            case .failure(let error):
                self.delegate?.provider(self, didFailWithError: error)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let resultText = json["result"] as? String {
            let isFinal = json["is_final"] as? Bool ?? false
            if isFinal {
                delegate?.provider(self, didFinishWithText: resultText)
            } else {
                delegate?.provider(self, didUpdateText: resultText)
            }
        }
    }

    private func convertToPCM16(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let floatData = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)
        var pcmData = Data(capacity: frameLength * 2)

        for i in 0..<frameLength {
            let sample = Int16(floatData[i] * 32767.0)
            var bigEndian = sample.bigEndian
            withUnsafePointer(to: &bigEndian) {
                pcmData.append(UnsafeBufferPointer(start: $0, count: 1))
            }
        }

        return pcmData
    }
}

enum TongyiError: Error {
    case missingCredentials
    case webSocketDisconnected
}
