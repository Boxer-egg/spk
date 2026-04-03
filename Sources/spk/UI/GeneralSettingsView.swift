import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var inputDevices: [AudioDevice] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("general.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 0) {
                        toggleRow(
                            title: NSLocalizedString("general.llm.title", comment: ""),
                            subtitle: NSLocalizedString("general.llm.subtitle", comment: ""),
                            isOn: $settings.isLLMEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: NSLocalizedString("general.clipboard.title", comment: ""),
                            subtitle: NSLocalizedString("general.clipboard.subtitle", comment: ""),
                            isOn: $settings.isCopyToClipboardEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: NSLocalizedString("general.history.title", comment: ""),
                            subtitle: NSLocalizedString("general.history.subtitle", comment: ""),
                            isOn: $settings.isHistoryEnabled
                        )

                        Divider().padding(.leading, 12)

                        inputDeviceRow(
                            title: NSLocalizedString("general.inputDevice.title", comment: ""),
                            devices: inputDevices,
                            selection: $settings.selectedInputDeviceUID
                        )
                    }
                }

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
        .onAppear {
            inputDevices = AudioDeviceManager.shared.enumerateInputDevices()
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

    @ViewBuilder
    private func inputDeviceRow(title: String, devices: [AudioDevice], selection: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                let uid = selection.wrappedValue
                if !uid.isEmpty, let device = devices.first(where: { $0.uid == uid }) {
                    Text(device.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Picker("", selection: selection) {
                Text(NSLocalizedString("general.inputDevice.systemDefault", comment: ""))
                    .tag("")
                ForEach(devices) { device in
                    Text(device.name)
                        .tag(device.uid)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
