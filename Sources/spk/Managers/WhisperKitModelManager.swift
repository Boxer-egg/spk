import Foundation
import WhisperKit

/// Manages local WhisperKit model lifecycle: download, load, and readiness.
@MainActor
final class WhisperKitModelManager: ObservableObject {
    static let shared = WhisperKitModelManager()

    @Published private(set) var state: ModelState = .idle
    @Published private(set) var downloadProgress: Double = 0
    private(set) var error: Error?

    private var whisperKit: WhisperKit?
    private var currentModelName: String?

    var isReady: Bool {
        state == .ready
    }

    enum ModelState: Equatable {
        case idle
        case loading
        case ready
        case error
    }

    static let availableModels = [
        (name: "openai_whisper-tiny", label: "Tiny (~75 MB)", sizeDescription: "~75 MB"),
        (name: "openai_whisper-tiny.en", label: "Tiny English (~75 MB)", sizeDescription: "~75 MB"),
        (name: "openai_whisper-base", label: "Base (~148 MB)", sizeDescription: "~148 MB"),
        (name: "openai_whisper-base.en", label: "Base English (~148 MB)", sizeDescription: "~148 MB"),
        (name: "openai_whisper-small", label: "Small (~466 MB)", sizeDescription: "~466 MB"),
        (name: "openai_whisper-small.en", label: "Small English (~466 MB)", sizeDescription: "~466 MB"),
    ]

    static let defaultModelName = "openai_whisper-small"

    private init() {}

    func loadModel(name: String) async {
        guard whisperKit == nil || currentModelName != name || state != .ready else {
            return
        }

        if let currentModelName, currentModelName != name {
            whisperKit = nil
        }

        state = .loading
        error = nil
        downloadProgress = 0
        currentModelName = name

        do {
            let modelsDir = Self.modelsDirectory
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

            let needsDownload = !Self.modelIsCached(name: name)
            if needsDownload {
                _ = try await WhisperKit.download(
                    variant: name,
                    downloadBase: modelsDir
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            }

            let config = WhisperKitConfig(
                model: name,
                downloadBase: modelsDir,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: true
            )
            whisperKit = try await WhisperKit(config)
            state = .ready
            downloadProgress = 1.0
        } catch {
            self.error = error
            self.state = .error
            self.whisperKit = nil
        }
    }

    func transcribe(audioBuffer: [Float], language: String? = nil) async -> String? {
        guard let whisperKit, state == .ready else { return nil }
        guard !audioBuffer.isEmpty else { return nil }

        do {
            var decodeOptions = DecodingOptions()
            if let language {
                decodeOptions.language = language
            } else {
                decodeOptions.detectLanguage = true
            }
            let results: [TranscriptionResult] = try await whisperKit.transcribe(
                audioArray: audioBuffer,
                decodeOptions: decodeOptions
            )
            let text = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = Self.removeArtifacts(from: text)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    static func removeArtifacts(from text: String) -> String {
        let artifacts: Set<String> = [
            "[BLANK_AUDIO]",
            "[NO_SPEECH]",
            "(blank audio)",
            "(no speech)",
            "[MUSIC]",
            "[APPLAUSE]",
            "[LAUGHTER]",
        ]
        var cleaned = text
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func modelIsCached(name: String) -> Bool {
        let modelPath = modelsDirectory.appendingPathComponent("models/openai/\(name)", isDirectory: true)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    private static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("spk/whisper-models", isDirectory: true)
    }
}
