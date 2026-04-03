import SwiftUI

struct PromptSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("prompt.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("prompt.system", comment: ""))
                            .font(.system(size: 13, weight: .medium))
                        Text(NSLocalizedString("prompt.subtitle", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $settings.systemPrompt)
                            .frame(minHeight: 200)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .background(Color(nsColor: .textBackgroundColor).cornerRadius(6))
                    }
                    .padding(14)
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
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
