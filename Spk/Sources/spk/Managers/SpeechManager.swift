import Foundation
import Speech
import AVFoundation

protocol SpeechManagerDelegate: AnyObject {
    func speechManager(_ manager: SpeechManager, didUpdateText text: String)
    func speechManager(_ manager: SpeechManager, didUpdateVolume volume: Float)
    func speechManager(_ manager: SpeechManager, didFinishWithText text: String)
    func speechManager(_ manager: SpeechManager, didFailWithError error: Error)
}

class SpeechManager: NSObject, SFSpeechRecognizerDelegate {
    weak var delegate: SpeechManagerDelegate?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var currentLanguage: Language = .zhCN {
        didSet {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage.rawValue))
            speechRecognizer?.delegate = self
        }
    }
    
    override init() {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage.rawValue))
        self.speechRecognizer?.delegate = self
    }
    
    func setLanguage(_ language: Language) {
        self.currentLanguage = language
    }
    
    func startRecording() throws {
        // Cancel previous task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // No AVAudioSession on macOS like iOS, but we need to check permissions
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            self.updateVolume(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.delegate?.speechManager(self, didUpdateText: result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if let result = result {
                    self.delegate?.speechManager(self, didFinishWithText: result.bestTranscription.formattedString)
                } else if let error = error {
                    self.delegate?.speechManager(self, didFailWithError: error)
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
    
    private func updateVolume(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<Int(frameLength) {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        // Normalize RMS to 0..1 roughly (adjust sensitivity)
        let normalized = min(1.0, rms * 5.0) 
        DispatchQueue.main.async {
            self.delegate?.speechManager(self, didUpdateVolume: normalized)
        }
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Handle availability
    }
}
