import Foundation
import Speech
import AVFoundation

protocol SpeechManagerDelegate: AnyObject {
    func speechManager(_ manager: SpeechManager, didUpdateText text: String)
    func speechManager(_ manager: SpeechManager, didUpdateVolume volume: Float)
    func speechManager(_ manager: SpeechManager, didFinishWithText text: String)
    func speechManager(_ manager: SpeechManager, didFailWithError error: Error)
}

class SpeechManager: NSObject {
    weak var delegate: SpeechManagerDelegate?

    private var currentProvider: SpeechRecognitionProvider?
    private var audioEngine = AVAudioEngine()

    private var currentLanguage: Language = .zhCN

    func setLanguage(_ language: Language) {
        self.currentLanguage = language
    }

    func startRecording() throws {
        if currentProvider != nil {
            currentProvider?.stop()
            currentProvider = nil
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)

        let provider: SpeechRecognitionProvider
        if SettingsManager.shared.selectedSpeechProvider == "doubao" {
            provider = DoubaoProvider()
        } else {
            provider = AppleSpeechProvider()
        }
        provider.delegate = self
        currentProvider = provider

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.updateVolume(from: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine = AVAudioEngine()
            AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)
            let fallbackNode = audioEngine.inputNode
            let fallbackFormat = fallbackNode.outputFormat(forBus: 0)
            fallbackNode.installTap(onBus: 0, bufferSize: 1024, format: fallbackFormat) { [weak self] (buffer, when) in
                self?.updateVolume(from: buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        }

        try provider.start(audioEngine: audioEngine)
    }

    func stopRecording() {
        currentProvider?.stop()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func updateVolume(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<Int(frameLength) {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let normalized = min(1.0, rms * 5.0)
        DispatchQueue.main.async {
            self.delegate?.speechManager(self, didUpdateVolume: normalized)
        }
    }
}

extension SpeechManager: SpeechRecognitionProviderDelegate {
    func provider(_ provider: SpeechRecognitionProvider, didUpdateText text: String) {
        delegate?.speechManager(self, didUpdateText: text)
    }

    func provider(_ provider: SpeechRecognitionProvider, didFinishWithText text: String) {
        delegate?.speechManager(self, didFinishWithText: text)
        currentProvider = nil
    }

    func provider(_ provider: SpeechRecognitionProvider, didFailWithError error: Error) {
        delegate?.speechManager(self, didFailWithError: error)
        currentProvider = nil
    }
}
