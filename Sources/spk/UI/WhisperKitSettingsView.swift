import SwiftUI

struct WhisperKitSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var modelManager = WhisperKitModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WhisperKit 本地语音识别")
                .font(.system(size: 13, weight: .medium))

            VStack(alignment: .leading, spacing: 4) {
                Text("模型选择")
                    .font(.system(size: 12))
                Picker("", selection: $settings.whisperKitModelName) {
                    ForEach(WhisperKitModelManager.availableModels, id: \.name) { model in
                        Text("\(model.label)").tag(model.name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.whisperKitModelName) { _, newName in
                    Task {
                        await modelManager.loadModel(name: newName)
                    }
                }
            }

            HStack(spacing: 8) {
                StatusBadge(state: modelManager.state)
                if modelManager.state == .loading {
                    ProgressView(value: modelManager.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 120)
                    Text("\(Int(modelManager.downloadProgress * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if let error = modelManager.error {
                Text("错误: \(error.localizedDescription)")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            Task {
                await modelManager.loadModel(name: settings.whisperKitModelName)
            }
        }
    }
}

private struct StatusBadge: View {
    let state: WhisperKitModelManager.ModelState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }

    private var color: Color {
        switch state {
        case .idle: return .gray
        case .loading: return .blue
        case .ready: return .green
        case .error: return .red
        }
    }

    private var text: String {
        switch state {
        case .idle: return "未加载"
        case .loading: return "加载中..."
        case .ready: return "就绪"
        case .error: return "错误"
        }
    }
}
