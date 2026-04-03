import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    let triggerKeys = ["Fn", "Left Ctrl", "Left Option", "Right Option"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("shortcuts.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("shortcuts.holdToSpeak", comment: ""))
                                    .font(.system(size: 13, weight: .medium))
                                Text(settings.isHoldToSpeak ? NSLocalizedString("shortcuts.hold.subtitle", comment: "") : NSLocalizedString("shortcuts.toggle.subtitle", comment: ""))
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
                            Text(NSLocalizedString("shortcuts.triggerKey", comment: ""))
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
                    Text(NSLocalizedString("shortcuts.hints", comment: ""))
                        .font(.headline)
                    if settings.isHoldToSpeak {
                        Text(NSLocalizedString("shortcuts.hint.hold", comment: ""))
                    } else {
                        Text(NSLocalizedString("shortcuts.hint.toggle", comment: ""))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

                HStack {
                    Spacer()
                    Text(NSLocalizedString("common.changesSaved", comment: ""))
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
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
