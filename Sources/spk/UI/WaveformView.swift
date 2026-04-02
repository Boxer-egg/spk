import SwiftUI

struct WaveformView: View {
    var volume: Float
    
    // 5 bars with weights [0.5, 0.8, 1.0, 0.75, 0.55]
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: max(4, 24 * CGFloat(volume) * weights[index]))
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: volume)
            }
        }
        .frame(height: 24)
    }
}
