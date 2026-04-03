import Foundation
import AVFoundation

class AudioRecorderManager {
    static let shared = AudioRecorderManager()

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    private let tapeDirectoryURL: URL

    private init() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spkSupportDir = appSupportDir.appendingPathComponent("spk", isDirectory: true)
        self.tapeDirectoryURL = spkSupportDir.appendingPathComponent("tape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tapeDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func startRecording() -> URL? {
        guard recorder == nil else { return nil }

        let filename = "\(UUID().uuidString).m4a"
        let url = tapeDirectoryURL.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            let success = recorder.record()
            guard success else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            self.recorder = recorder
            self.currentURL = url
            return url
        } catch {
            print("Failed to start audio recording: \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    func stopRecording() -> URL? {
        guard recorder != nil else { return nil }
        recorder?.stop()
        let url = currentURL
        recorder = nil
        currentURL = nil
        return url
    }

    func urlForAudio(named filename: String) -> URL {
        let safeName = (filename as NSString).lastPathComponent
        return tapeDirectoryURL.appendingPathComponent(safeName)
    }

    func removeOrphanedAudioFiles(referencedFilenames: [String]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: tapeDirectoryURL, includingPropertiesForKeys: nil) else { return }
        let referencedSet = Set(referencedFilenames)
        for url in contents where url.pathExtension.lowercased() == "m4a" {
            if !referencedSet.contains(url.lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
