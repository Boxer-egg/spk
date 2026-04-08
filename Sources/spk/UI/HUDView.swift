import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel = HUDViewModel.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status Indicator Area
            VStack(spacing: 8) {
                if viewModel.state == .listening {
                    WaveformView(volume: viewModel.volume)
                } else if viewModel.state == .refining {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("hud.refining", comment: ""))
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
            .frame(width: 50)
            .padding(.top, 4)
            
            // Text Area with Vertical ScrollView and Fade Effect
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewModel.text.isEmpty ? (viewModel.state == .listening ? NSLocalizedString("hud.listening", comment: "") : NSLocalizedString("hud.processing", comment: "")) : viewModel.text)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(viewModel.text.isEmpty ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("textContent")
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                    }
                    .padding(.top, 10) // Small top padding for the fade mask to work better
                }
                .frame(minHeight: 80, maxHeight: 180) // Set min/max height to ensure ~3-5 lines
                // Fade-out mask at the top
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.15), // Fade in quickly from the top
                            .init(color: .black, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: viewModel.text) {
                    HUDPanel.shared.updateFrame()
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(minWidth: 220, maxWidth: 600)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .scaleEffect(viewModel.isVisible ? 1.0 : 0.8)
        .opacity(viewModel.isVisible ? 1.0 : 0)
        .padding(40)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isVisible)
        .onChange(of: viewModel.state) {
            HUDPanel.shared.updateFrame()
        }
    }
}
