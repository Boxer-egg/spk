import Foundation
import Combine

enum HUDState {
    case listening
    case refining
    case success
    case error
}

class HUDViewModel: ObservableObject {
    static let shared = HUDViewModel()
    
    @Published var text: String = ""
    @Published var volume: Float = 0
    @Published var state: HUDState = .listening
    @Published var isVisible: Bool = false
    
    func reset() {
        text = ""
        volume = 0
        state = .listening
    }
}
