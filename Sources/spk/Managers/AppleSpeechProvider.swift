import Foundation
import Speech
import AVFoundation

class AppleSpeechProvider: NSObject, SpeechRecognitionProvider, SFSpeechRecognizerDelegate {
    weak var delegate: SpeechRecognitionProviderDelegate?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func start(audioEngine: AVAudioEngine) throws {
        let language = SettingsManager.shared.selectedLanguage
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
        speechRecognizer?.delegate = self

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AppleSpeechError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.delegate?.provider(self, didUpdateText: result.bestTranscription.formattedString)
                if result.isFinal {
                    self.delegate?.provider(self, didFinishWithText: result.bestTranscription.formattedString)
                }
            } else if let error = error {
                self.delegate?.provider(self, didFailWithError: error)
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {}
}

enum AppleSpeechError: Error {
    case unableToCreateRequest
}
