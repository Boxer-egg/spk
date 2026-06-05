import Foundation
import AVFoundation

class AudioRecorderManager {
    static let shared = AudioRecorderManager()

    private var recorders: [String: AVAudioRecorder] = [:]
    private var currentURLs: [String: URL] = [:]
    private let lock = NSLock()

    private let tapeDirectoryURL: URL

    private init() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spkSupportDir = appSupportDir.appendingPathComponent("spk", isDirectory: true)
        self.tapeDirectoryURL = spkSupportDir.appendingPathComponent("tape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tapeDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func startRecording(identifier: String = "default") -> URL? {
        lock.lock()
        defer { lock.unlock() }

        guard recorders[identifier] == nil else { return nil }

        let filename = "\(identifier)_\(UUID().uuidString).m4a"
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
            self.recorders[identifier] = recorder
            self.currentURLs[identifier] = url
            return url
        } catch {
            print("Failed to start audio recording: \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    func stopRecording(identifier: String = "default") -> URL? {
        lock.lock()
        defer { lock.unlock() }

        guard let recorder = recorders[identifier] else { return nil }
        recorder.stop()
        let url = currentURLs[identifier]
        recorders.removeValue(forKey: identifier)
        currentURLs.removeValue(forKey: identifier)
        return url
    }

    func stopAllRecordings() {
        lock.lock()
        defer { lock.unlock() }
        for (_, recorder) in recorders {
            recorder.stop()
        }
        recorders.removeAll()
        currentURLs.removeAll()
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
