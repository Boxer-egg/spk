import Foundation
import AVFoundation

class WhisperKitProvider: SpeechRecognitionProvider {
    weak var delegate: SpeechRecognitionProviderDelegate?
    private var isRunning = false
    private let bufferLock = NSLock()
    private var audioBuffer: [Float] = []

    private lazy var targetFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    }()
    private var cachedConverter: AVAudioConverter?
    private var cachedSourceFormat: AVAudioFormat?

    func start(audioEngine: AVAudioEngine) throws {
        isRunning = true
        audioBuffer = []

    }

    func consumeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }
        guard let converted = convert(buffer: buffer) else { return }
        bufferLock.lock()
        audioBuffer.append(contentsOf: converted)
        bufferLock.unlock()
    }

    func stop() {
        isRunning = false

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        guard !samples.isEmpty else {
            delegate?.provider(self, didFailWithError: WhisperKitProviderError.noAudioData)
            return
        }

        Task {
            let language = SettingsManager.shared.selectedLanguage.whisperLanguageCode
            if let text = await WhisperKitModelManager.shared.transcribe(audioBuffer: samples, language: language) {
                delegate?.provider(self, didFinishWithText: text)
            } else {
                delegate?.provider(self, didFailWithError: WhisperKitProviderError.transcriptionFailed)
            }
        }
    }

    private func convert(buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let converter = self.converter(for: buffer.format) else { return nil }

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (targetFormat.sampleRate / buffer.format.sampleRate)
        ) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return nil
        }

        var error: NSError?
        var allConsumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if allConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            allConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil,
              let channelData = convertedBuffer.floatChannelData,
              convertedBuffer.frameLength > 0 else {
            return nil
        }

        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength)))
    }

    private func converter(for sourceFormat: AVAudioFormat) -> AVAudioConverter? {
        if let cachedConverter = cachedConverter,
           let cachedSourceFormat = cachedSourceFormat,
           cachedSourceFormat.sampleRate == sourceFormat.sampleRate,
           cachedSourceFormat.channelCount == sourceFormat.channelCount {
            return cachedConverter
        }
        let converter = AVAudioConverter(from: sourceFormat, to: targetFormat)
        cachedConverter = converter
        cachedSourceFormat = sourceFormat
        return converter
    }
}

enum WhisperKitProviderError: Error, LocalizedError {
    case modelNotReady
    case noAudioData
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "WhisperKit model is not loaded. Please wait for the model to download or restart the app."
        case .noAudioData:
            return "No audio data was captured."
        case .transcriptionFailed:
            return "Transcription failed. Please try again."
        }
    }
}
