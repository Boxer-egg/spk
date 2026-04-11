import SwiftUI

struct APISettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    @State private var testStatus: String = ""
    @State private var isTesting: Bool = false
    @State private var testDuration: TimeInterval = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("api.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                card {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localized("api.baseURL"))
                                .font(.system(size: 13, weight: .medium))
                            TextField("", text: $settings.apiBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localized("api.key"))
                                .font(.system(size: 13, weight: .medium))
                            SecureField("", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(localized("api.model"))
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
                        Label(localized("api.test"), systemImage: "bolt.horizontal.fill")
                    }
                    .disabled(isTesting || settings.apiKey.isEmpty)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text(localized("api.testing"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                statusCard

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
            return (Color.secondary.opacity(0.3), "info.circle", localized("api.status.info"))
        } else if testStatus.contains(localized("api.status.success")) {
            let format = localized("api.status.time")
            let timeStr = String(format: "%.2f", testDuration)
            return (.green, "checkmark.circle.fill", String(format: format, testStatus, timeStr))
        } else {
            let format = localized("api.status.time")
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
                    testStatus = localized("api.status.success")
                case .failure(let error):
                    testStatus = String(format: localized("api.status.error"), error.localizedDescription)
                }
            }
        }
    }
}
