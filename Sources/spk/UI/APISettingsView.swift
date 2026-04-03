import SwiftUI

struct APISettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    @State private var testStatus: String = ""
    @State private var isTesting: Bool = false
    @State private var testDuration: TimeInterval = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Base URL")
                                .font(.system(size: 13, weight: .medium))
                            TextField("", text: $settings.apiBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key")
                                .font(.system(size: 13, weight: .medium))
                            SecureField("", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model")
                                .font(.system(size: 13, weight: .medium))
                            TextField("", text: $settings.model)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(14)
                }

                // Test Connection
                HStack(spacing: 12) {
                    Button(action: testConnection) {
                        Label("Test Connection", systemImage: "bolt.horizontal.fill")
                    }
                    .disabled(isTesting || settings.apiKey.isEmpty)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text("Testing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                statusCard

                Spacer(minLength: 20)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        let config = statusConfiguration()

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: config.icon)
                .foregroundColor(config.borderColor)
            Text(config.message)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(config.borderColor, lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func statusConfiguration() -> (borderColor: Color, icon: String, message: String) {
        if testStatus.isEmpty {
            return (Color.secondary.opacity(0.3), "info.circle", "Click the button above to test connection status")
        } else if testStatus.contains("Successful") {
            return (.green, "checkmark.circle.fill", "\(testStatus)（耗时 \(String(format: "%.2f", testDuration))s）")
        } else {
            return (.red, "xmark.circle.fill", "\(testStatus)（耗时 \(String(format: "%.2f", testDuration))s）")
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }

    private func testConnection() {
        isTesting = true
        testStatus = ""
        let start = Date()
        LLMManager.shared.testConnection { result in
            DispatchQueue.main.async {
                isTesting = false
                testDuration = Date().timeIntervalSince(start)
                switch result {
                case .success(let msg):
                    testStatus = msg
                case .failure(let error):
                    testStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
