import SwiftUI

struct WaveformView: View {
    var volume: Float
    
    // 5 dots weights for a nice wave shape
    private let weights: [CGFloat] = [0.7, 1.2, 1.5, 1.2, 0.7]
    
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
                    // 1. Idle wave motion + 2. Volume-based vertical jump
                    .offset(y: calculateOffset(index: index))
                    // Scale up slightly with volume
                    .scaleEffect(1.0 + CGFloat(volume) * 0.6)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: volume)
            }
        }
        .frame(height: 30)
        .onAppear {
            // Continuous idle wave animation
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
    
    private func calculateOffset(index: Int) -> CGFloat {
        // Subtle sine wave for idle state
        let idleOffset = sin(phase + CGFloat(index) * 0.7) * 2.5
        // Strong jump based on volume
        let activeOffset = -CGFloat(volume) * 18.0 * weights[index]
        return idleOffset + activeOffset
    }
}
