import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 0) {
                        toggleRow(
                            title: "Enable LLM Correction",
                            subtitle: "Refine speech with AI before pasting",
                            isOn: $settings.isLLMEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: "Copy to Clipboard",
                            subtitle: "Save final output automatically",
                            isOn: $settings.isCopyToClipboardEnabled
                        )

                        Divider().padding(.leading, 12)

                        toggleRow(
                            title: "Record History",
                            subtitle: "Save transcriptions (max 20 entries)",
                            isOn: $settings.isHistoryEnabled
                        )
                    }
                }

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
