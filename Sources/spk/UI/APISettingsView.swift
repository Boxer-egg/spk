import SwiftUI

struct APISettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    @State private var testStatus: String = ""
    @State private var isTesting: Bool = false
    @State private var testDuration: TimeInterval = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("api.title", comment: ""))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("api.baseURL", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                            TextField("", text: $settings.apiBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("api.key", comment: ""))
                                .font(.system(size: 13, weight: .medium))
                            SecureField("", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("api.model", comment: ""))
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
                        Label(NSLocalizedString("api.test", comment: ""), systemImage: "bolt.horizontal.fill")
                    }
                    .disabled(isTesting || settings.apiKey.isEmpty)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text(NSLocalizedString("api.testing", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                statusCard

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
            return (Color.secondary.opacity(0.3), "info.circle", NSLocalizedString("api.status.info", comment: ""))
        } else if testStatus.contains(NSLocalizedString("api.status.success", comment: "")) {
            let format = NSLocalizedString("api.status.time", comment: "")
            let timeStr = String(format: "%.2f", testDuration)
            return (.green, "checkmark.circle.fill", String(format: format, testStatus, timeStr))
        } else {
            let format = NSLocalizedString("api.status.time", comment: "")
            let timeStr = String(format: "%.2f", testDuration)
            return (.red, "xmark.circle.fill", String(format: format, testStatus, timeStr))
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
                case .success:
                    testStatus = NSLocalizedString("api.status.success", comment: "")
                case .failure(let error):
                    testStatus = String(format: NSLocalizedString("api.status.error", comment: ""), error.localizedDescription)
                }
            }
        }
    }
}
