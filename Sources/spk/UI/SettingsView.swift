import SwiftUI

struct SettingsView: View {
    @State private var apiBaseURL: String = SettingsManager.shared.apiBaseURL
    @State private var apiKey: String = SettingsManager.shared.apiKey
    @State private var model: String = SettingsManager.shared.model
    @State private var isEnabled: Bool = SettingsManager.shared.isLLMEnabled
    @State private var systemPrompt: String = SettingsManager.shared.systemPrompt
    
    @State private var testStatus: String = ""
    @State private var isTesting: Bool = false
    
    var body: some View {
        Form {
            Section("LLM Refinement") {
                Toggle("Enable LLM Correction", isOn: $isEnabled)
                TextField("API Base URL", text: $apiBaseURL)
                SecureField("API Key", text: $apiKey)
                TextField("Model", text: $model)
                
                VStack(alignment: .leading) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $systemPrompt)
                        .frame(height: 80)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                }
            }
            
            VStack {
                HStack {
                    if isTesting {
                        ProgressView().scaleEffect(0.5).frame(width: 20, height: 20)
                    }
                    Text(testStatus)
                        .font(.caption)
                        .foregroundColor(testStatus.contains("Successful") ? .green : .red)
                    
                    Spacer()
                    
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting || apiKey.isEmpty)
                    
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 450)
    }
    
    private func saveSettings() {
        SettingsManager.shared.apiBaseURL = apiBaseURL
        SettingsManager.shared.apiKey = apiKey
        SettingsManager.shared.model = model
        SettingsManager.shared.isLLMEnabled = isEnabled
        SettingsManager.shared.systemPrompt = systemPrompt
    }
    
    private func testConnection() {
        isTesting = true
        testStatus = "Testing..."
        
        // Temporarily save to manager for test
        let originalPrompt = SettingsManager.shared.systemPrompt
        let originalBase = SettingsManager.shared.apiBaseURL
        let originalKey = SettingsManager.shared.apiKey
        let originalModel = SettingsManager.shared.model
        
        SettingsManager.shared.apiBaseURL = apiBaseURL
        SettingsManager.shared.apiKey = apiKey
        SettingsManager.shared.model = model
        SettingsManager.shared.systemPrompt = systemPrompt
        SettingsManager.shared.isLLMEnabled = true
        
        LLMManager.shared.testConnection { result in
            DispatchQueue.main.async {
                isTesting = false
                switch result {
                case .success(let msg):
                    testStatus = msg
                case .failure(let error):
                    testStatus = "Error: \(error.localizedDescription)"
                }
                
                // Restore
                SettingsManager.shared.systemPrompt = originalPrompt
                SettingsManager.shared.apiBaseURL = originalBase
                SettingsManager.shared.apiKey = originalKey
                SettingsManager.shared.model = originalModel
            }
        }
    }
}
