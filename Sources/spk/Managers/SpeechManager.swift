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

    /// Pre-warms the audio engine so the first recording starts faster.
    /// Call this after app launch or when the input device changes.
    func prewarm() {
        rebuildEngine()
        AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)
        _ = audioEngine.inputNode
        audioEngine.prepare()
    }

    func startRecording() throws {
        if currentProvider != nil {
            currentProvider?.stop()
            currentProvider = nil
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        rebuildEngine()
        AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)

        let provider: SpeechRecognitionProvider
        switch SettingsManager.shared.selectedSpeechProvider {
        case "doubao":
            provider = DoubaoProvider()
        case "tongyi":
            provider = TongyiProvider()
        case "whisper":
            provider = WhisperProvider()
        case "whisperkit":
            provider = WhisperKitProvider()
        default:
            provider = AppleSpeechProvider()
        }
        provider.delegate = self
        currentProvider = provider

        // Whisper needs an audio file for upload
        if SettingsManager.shared.selectedSpeechProvider == "whisper" {
            _ = AudioRecorderManager.shared.startRecording()
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw SpeechManagerError.noInputAvailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.updateVolume(from: buffer)
        }

        audioEngine.prepare()
        do {
            try startEngineWithTimeout()
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            rebuildEngine()
            AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)
            let fallbackNode = audioEngine.inputNode
            let fallbackFormat = fallbackNode.inputFormat(forBus: 0)
            guard fallbackFormat.sampleRate > 0, fallbackFormat.channelCount > 0 else {
                throw SpeechManagerError.noInputAvailable
            }
            fallbackNode.installTap(onBus: 0, bufferSize: 1024, format: fallbackFormat) { [weak self] (buffer, when) in
                self?.updateVolume(from: buffer)
            }
            audioEngine.prepare()
            try startEngineWithTimeout()
        }

        try provider.start(audioEngine: audioEngine)
    }

    func stopRecording() {
        currentProvider?.stop()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    /// Rebuilds the audio engine so inputNode picks up the new device's format.
    /// Call this after changing the microphone selection.
    private func rebuildEngine() {
        audioEngine.stop()
        audioEngine = AVAudioEngine()
    }

    /// Starts the audio engine on a background thread with a timeout.
    /// Prevents indefinite main-thread hang when CoreAudio's HAL proxy
    /// blocks after a device route change (see koe missuo/koe#77).
    private func startEngineWithTimeout(timeout: TimeInterval = 3.0) throws {
        let engine = self.audioEngine
        let semaphore = DispatchSemaphore(value: 0)
        var startError: Error?

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try engine.start()
            } catch {
                startError = error
            }
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + timeout)
        if result == .timedOut {
            DispatchQueue.global(qos: .default).async {
                engine.stop()
            }
            throw SpeechManagerError.engineStartTimeout
        }

        if let error = startError {
            throw error
        }
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

enum SpeechManagerError: Error, LocalizedError {
    case noInputAvailable
    case engineStartTimeout

    var errorDescription: String? {
        switch self {
        case .noInputAvailable:
            return "No audio input device available."
        case .engineStartTimeout:
            return "Audio engine start timed out. The input device may be busy or disconnected."
        }
    }
}
