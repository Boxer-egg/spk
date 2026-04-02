import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel = HUDViewModel.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // Status Indicator Area
            VStack(spacing: 8) {
                if viewModel.state == .listening {
                    WaveformView(volume: viewModel.volume)
                } else if viewModel.state == .refining {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Refining...")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.accentColor)
                } else if viewModel.state == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 24))
                }
            }
            .frame(width: 60)
            
            // Text Area
            Text(viewModel.text.isEmpty ? (viewModel.state == .listening ? "Listening..." : "Processing...") : viewModel.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .foregroundColor(viewModel.text.isEmpty ? .secondary : .primary)
                .frame(minWidth: 100)
                .padding(.vertical, 8)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
        .frame(minWidth: 200, maxWidth: 600)
        .frame(minHeight: 70)
        .background(
            RoundedRectangle(cornerRadius: 35, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .scaleEffect(viewModel.isVisible ? 1.0 : 0.8)
        .opacity(viewModel.isVisible ? 1.0 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.text)
    }
}
