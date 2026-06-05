import Foundation
import Speech
import AVFoundation

class AppleSpeechProvider: NSObject, SpeechRecognitionProvider, SFSpeechRecognizerDelegate {
    weak var delegate: SpeechRecognitionProviderDelegate?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    var isStoppingIntentionally = false

    func start(audioEngine: AVAudioEngine) throws {
        let language = SettingsManager.shared.selectedLanguage
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
        
        guard let recognizer = recognizer else {
            throw AppleSpeechError.recognizerNotAvailable
        }
        
        if !recognizer.isAvailable {
            throw AppleSpeechError.recognizerNotAvailable
        }
        
        self.speechRecognizer = recognizer
        recognizer.delegate = self

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AppleSpeechError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true
        
        // Use on-device recognition if available for better performance and privacy
        if #available(macOS 10.15, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.delegate?.provider(self, didUpdateText: result.bestTranscription.formattedString)
                if result.isFinal {
                    self.delegate?.provider(self, didFinishWithText: result.bestTranscription.formattedString)
                    self.cleanup()
                }
            } else if let error = error {
                if self.isStoppingIntentionally {
                    // User intentionally stopped recording; treat as normal finish.
                    self.delegate?.provider(self, didFinishWithText: "")
                } else {
                    self.delegate?.provider(self, didFailWithError: error)
                }
                self.cleanup()
            }
        }
    }

    func consumeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        isStoppingIntentionally = true
        // Signal the end of audio, allowing the task to finish processing the remaining buffers.
        recognitionRequest?.endAudio()
    }

    // Internal for testability
    func cleanup() {
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isStoppingIntentionally = false
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {}
}

enum AppleSpeechError: Error, LocalizedError {
    case unableToCreateRequest
    case recognizerNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available for the selected language."
        }
    }
}
