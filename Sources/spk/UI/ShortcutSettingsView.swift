import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    let triggerKeys = ["Fn", "Left Ctrl", "Left Option", "Right Option"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hold to Speak")
                                    .font(.system(size: 13, weight: .medium))
                                Text(settings.isHoldToSpeak ? "Press and hold to record" : "Toggle mode: click to start/stop")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.isHoldToSpeak)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 12)

                        HStack {
                            Text("Trigger Key")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Picker("", selection: $settings.triggerKey) {
                                ForEach(triggerKeys, id: \.self) { key in
                                    Text(key).tag(key)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage Hints")
                        .font(.headline)
                    if settings.isHoldToSpeak {
                        Text("Press and hold the selected key to record.\nRelease to finish.")
                    } else {
                        Text("Click the key once to start.\nClick it again to stop.")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
