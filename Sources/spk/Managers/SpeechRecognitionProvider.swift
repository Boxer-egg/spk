import Foundation
import AVFoundation

protocol SpeechRecognitionProvider: AnyObject {
    var delegate: SpeechRecognitionProviderDelegate? { get set }
    func start(audioEngine: AVAudioEngine) throws
    func stop()
}

protocol SpeechRecognitionProviderDelegate: AnyObject {
    func provider(_ provider: SpeechRecognitionProvider, didUpdateText text: String)
    func provider(_ provider: SpeechRecognitionProvider, didFinishWithText text: String)
    func provider(_ provider: SpeechRecognitionProvider, didFailWithError error: Error)
}
