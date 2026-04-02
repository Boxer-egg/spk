import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    @State private var testStatus: String = ""
    @State private var isTesting: Bool = false
    
    let triggerKeys = ["Fn", "Left Ctrl", "Left Option", "Right Option"]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // Tab 1: General
                Form {
                    Section("Core Features") {
                        Toggle("Enable LLM Correction", isOn: $settings.isLLMEnabled)
                        Text("When enabled, your speech will be refined by the selected AI model before being pasted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
                .padding()

                // Tab 2: API Settings
                Form {
                    Section("Endpoint Configuration") {
                        TextField("API Base URL", text: $settings.apiBaseURL)
                        SecureField("API Key", text: $settings.apiKey)
                        TextField("Model", text: $settings.model)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button(action: testConnection) {
                                Label("Test Connection", systemImage: "bolt.horizontal.fill")
                            }
                            .disabled(isTesting || settings.apiKey.isEmpty)
                            
                            if isTesting {
                                ProgressView().scaleEffect(0.5).frame(width: 20, height: 20)
                            }
                            
                            Text(testStatus)
                                .font(.caption)
                                .foregroundColor(testStatus.contains("Successful") ? .green : .red)
                        }
                    }
                    .padding(.top, 10)
                }
                .tabItem {
                    Label("API Settings", systemImage: "network")
                }
                .padding()

                // Tab 3: AI Prompt
                Form {
                    Section("Refinement Logic") {
                        VStack(alignment: .leading) {
                            Text("System Prompt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $settings.systemPrompt)
                                .frame(minHeight: 200)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2)))
                        }
                    }
                }
                .tabItem {
                    Label("AI Prompt", systemImage: "text.bubble.fill")
                }
                .padding()
                
                // Tab 4: Shortcuts
                Form {
                    Section("Interaction") {
                        Toggle("Hold to Speak (Release to Stop)", isOn: $settings.isHoldToSpeak)
                        
                        Picker("Trigger Key", selection: $settings.triggerKey) {
                            ForEach(triggerKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Usage Hints:")
                            .font(.headline)
                        if settings.isHoldToSpeak {
                            Text("• Press and hold the selected key to record.\n• Release to finish.")
                        } else {
                            Text("• Click the key once to start.\n• Click it again to stop.")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
                }
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard.fill")
                }
                .padding()
            }
            .frame(height: 380)
            
            Divider()
            
            HStack {
                Spacer()
                Text("Changes are saved automatically")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 550, height: 450)
    }
    
    private func testConnection() {
        isTesting = true
        testStatus = "Testing..."
        
        LLMManager.shared.testConnection { result in
            DispatchQueue.main.async {
                isTesting = false
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
