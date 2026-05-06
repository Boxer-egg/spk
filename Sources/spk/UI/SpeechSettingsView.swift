import SwiftUI

struct SpeechSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("speech.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localized("speech.engine.title"))
                            .font(.system(size: 13, weight: .medium))

                        Picker("", selection: $settings.selectedSpeechProvider) {
                            Text("Apple Speech").tag("apple")
                            Text("豆包 (ByteDance)").tag("doubao")
                            Text("通义 (Alibaba)").tag("tongyi")
                            Text("Whisper (OpenAI)").tag("whisper")
                            Text("WhisperKit (本地)").tag("whisperkit")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(14)
                }

                if settings.selectedSpeechProvider == "doubao" {
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("豆包语音识别配置")
                                .font(.system(size: 13, weight: .medium))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("App ID")
                                    .font(.system(size: 12))
                                TextField("", text: $settings.doubaoAppId)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Access Token")
                                    .font(.system(size: 12))
                                SecureField("", text: $settings.doubaoAccessToken)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(14)
                    }
                }

                if settings.selectedSpeechProvider == "tongyi" {
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("通义语音识别配置")
                                .font(.system(size: 13, weight: .medium))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.system(size: 12))
                                SecureField("", text: $settings.tongyiApiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(14)
                    }
                }

                if settings.selectedSpeechProvider == "whisper" {
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Whisper 语音识别配置")
                                .font(.system(size: 13, weight: .medium))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.system(size: 12))
                                SecureField("", text: $settings.whisperApiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(14)
                    }
                }

                if settings.selectedSpeechProvider == "whisperkit" {
                    WhisperKitSettingsView()
                }

                HStack {
                    Spacer()
                    Text(localized("common.changesSaved"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 8)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
