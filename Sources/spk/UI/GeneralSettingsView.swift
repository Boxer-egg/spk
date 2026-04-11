import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("general.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 0) {
                        toggleRow(
                            title: localized("general.llm.title"),
                            subtitle: localized("general.llm.subtitle"),
                            isOn: $settings.isLLMEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: localized("general.clipboard.title"),
                            subtitle: localized("general.clipboard.subtitle"),
                            isOn: $settings.isCopyToClipboardEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: localized("general.history.title"),
                            subtitle: localized("general.history.subtitle"),
                            isOn: $settings.isHistoryEnabled
                        )

                        if settings.isHistoryEnabled {
                            VStack(alignment: .leading, spacing: 0) {
                                Divider().padding(.leading, 12)
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(localized("general.history.audio.title"))
                                            .font(.system(size: 13, weight: .medium))
                                        Text(localized("general.history.audio.subtitle"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $settings.isHistoryAudioEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                        }

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: localized("general.antimisclick.title"),
                            subtitle: localized("general.antimisclick.subtitle"),
                            isOn: $settings.isAntiMisclickEnabled
                        )
                    }
                }

                Text(localized("shortcuts.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                card {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localized("shortcuts.holdToSpeak"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(settings.isHoldToSpeak ? localized("shortcuts.hold.subtitle") : localized("shortcuts.toggle.subtitle"))
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
                            Text(localized("shortcuts.triggerKey"))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Picker("", selection: $settings.triggerKey) {
                                ForEach(["Fn", "Left Ctrl", "Left Option", "Right Option"], id: \.self) { key in
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
                    Text(localized("shortcuts.hints"))
                        .font(.headline)
                    if settings.isHoldToSpeak {
                        Text(localized("shortcuts.hint.hold"))
                    } else {
                        Text(localized("shortcuts.hint.toggle"))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

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
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }

    @ViewBuilder
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

}
