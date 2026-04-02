import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel = HUDViewModel.shared
    @State private var pulse: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            if viewModel.state == .listening {
                WaveformView(volume: viewModel.volume)
            } else if viewModel.state == .refining {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else if viewModel.state == .success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.state == .refining {
                    Text("AI Refining...")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                        .transition(.opacity)
                }
                
                Text(viewModel.text.isEmpty ? (viewModel.state == .listening ? "Listening..." : "Processing...") : viewModel.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundColor(viewModel.text.isEmpty ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.text)
            }
        }
        .padding(.horizontal, 24)
        .frame(minWidth: 160, maxWidth: 560)
        .frame(height: 56)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .scaleEffect(viewModel.isVisible ? 1.0 : 0.8)
        .opacity(viewModel.isVisible ? 1.0 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.isVisible)
        .onAppear {
            if viewModel.state == .listening {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = 1.1
                }
            }
        }
    }
}
