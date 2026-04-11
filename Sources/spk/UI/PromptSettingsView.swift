import SwiftUI

struct PromptSettingsView: View {
    @State private var promptText: String = ""
    private let promptURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/spk/prompts/skills/default_paste.prompt", isDirectory: false)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("prompt.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Paste Prompt")
                            .font(.system(size: 13, weight: .medium))
                        Text("This prompt is used when no specific skill matches your voice input.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $promptText)
                            .frame(minHeight: 200)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .background(Color(nsColor: .textBackgroundColor).cornerRadius(6))
                            .onChange(of: promptText) {
                                savePrompt()
                            }
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
        .onAppear {
            loadPrompt()
        }
    }

    private func loadPrompt() {
        if FileManager.default.fileExists(atPath: promptURL.path) {
            if let content = try? String(contentsOf: promptURL, encoding: .utf8) {
                promptText = content
                return
            }
        }
        // Fallback to bundled default
        if let bundledURL = Bundle.main.url(forResource: "skills/default_paste", withExtension: "prompt", subdirectory: "Prompts"),
           let content = try? String(contentsOf: bundledURL, encoding: .utf8) {
            promptText = content
        }
    }

    private func savePrompt() {
        try? promptText.write(to: promptURL, atomically: true, encoding: .utf8)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
