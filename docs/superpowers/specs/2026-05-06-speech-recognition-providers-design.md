# Spk 语音识别引擎扩展设计文档（简化版）

## 1. 目标

让 Spk 支持切换语音识别引擎。第一轮只实现 **Apple Speech（现有）+ 豆包（云端）**。

**成功标准**：
1. 在设置里选择"豆包"，填入 App ID 和 Access Token，按住 Fn 说话，能看到实时转写结果
2. 切换回"Apple Speech"，功能和不改之前一模一样
3. 现有菜单栏、HUD、历史记录功能不受影响

## 2. 核心架构

### 2.1 Provider 协议（2 个方法）

```swift
protocol SpeechRecognitionProvider: AnyObject {
    var delegate: SpeechRecognitionProviderDelegate? { get set }
    func start(audioEngine: AVAudioEngine) throws
    func stop()
}

protocol SpeechRecognitionProviderDelegate: AnyObject {
    func provider(_ provider: SpeechRecognitionProvider, didUpdateText text: String)
    func provider(_ provider: SpeechRecognitionProvider, didFinishWithText text: String)
    func provider(_ provider: SpeechRecognitionProvider, didFailWithError error: Error)
}
```

**设计决策**：
- 流式 Provider（Apple Speech、豆包）在 `start` 时自己装 tap，实时接收 buffer
- 文件型 Provider（以后的 Whisper）在 `start` 时忽略 audioEngine，在 `stop` 时读 `AudioRecorderManager` 的文件
- 音量计算仍在 `SpeechManager` 中统一处理

### 2.2 SpeechManager 改动

只改两行：创建 Provider 的地方，和调用 Provider 的地方。

```swift
class SpeechManager: NSObject {
    weak var delegate: SpeechManagerDelegate?
    
    private var currentProvider: SpeechRecognitionProvider?
    private var audioEngine = AVAudioEngine()
    // 其他代码不变...
    
    func startRecording() throws {
        // 1. 根据设置创建 Provider（唯一新增逻辑）
        let provider: SpeechRecognitionProvider
        if SettingsManager.shared.selectedSpeechProvider == "doubao" {
            provider = DoubaoProvider()
        } else {
            provider = AppleSpeechProvider()
        }
        provider.delegate = self
        self.currentProvider = provider
        
        // 2. 配置音频引擎（现有逻辑不变）
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        AudioDeviceManager.shared.bindEngine(audioEngine, toDeviceUID: SettingsManager.shared.selectedInputDeviceUID)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 3. 安装音频采集回调（现有逻辑不变）
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.updateVolume(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // 4. 启动 Provider（替代原来的 speechRecognizer 初始化）
        try provider.start(audioEngine: audioEngine)
    }
    
    func stopRecording() {
        currentProvider?.stop()  // 替代原来的 recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - SpeechRecognitionProviderDelegate
extension SpeechManager: SpeechRecognitionProviderDelegate {
    func provider(_ provider: SpeechRecognitionProvider, didUpdateText text: String) {
        delegate?.speechManager(self, didUpdateText: text)
    }
    
    func provider(_ provider: SpeechRecognitionProvider, didFinishWithText text: String) {
        delegate?.speechManager(self, didFinishWithText: text)
        currentProvider = nil
    }
    
    func provider(_ provider: SpeechRecognitionProvider, didFailWithError error: Error) {
        delegate?.speechManager(self, didFailWithError: error)
        currentProvider = nil
    }
}
```

**关键**：`SpeechManager` 的音频采集逻辑（AVAudioEngine、inputNode、installTap）基本不变，只是把 `SFSpeechRecognizer` 的创建和回调替换成了 Provider 的创建和回调。

### 2.3 Provider 实现

#### AppleSpeechProvider

把现有 `SpeechManager` 中的 `SFSpeechRecognizer` 逻辑搬过来。

```swift
class AppleSpeechProvider: NSObject, SpeechRecognitionProvider, SFSpeechRecognizerDelegate {
    weak var delegate: SpeechRecognitionProviderDelegate?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func start(audioEngine: AVAudioEngine) throws {
        let language = SettingsManager.shared.selectedLanguage
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
        speechRecognizer?.delegate = self
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.delegate?.provider(self, didUpdateText: result.bestTranscription.formattedString)
                if result.isFinal {
                    self.delegate?.provider(self, didFinishWithText: result.bestTranscription.formattedString)
                }
            } else if let error = error {
                self.delegate?.provider(self, didFailWithError: error)
            }
        }
        
        // 自己装 tap 接收音频
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }
    }
    
    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
```

#### DoubaoProvider

```swift
class DoubaoProvider: SpeechRecognitionProvider {
    weak var delegate: SpeechRecognitionProviderDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    
    func start(audioEngine: AVAudioEngine) throws {
        let appId = SettingsManager.shared.doubaoAppId
        let accessToken = SettingsManager.shared.doubaoAccessToken
        
        guard !appId.isEmpty, !accessToken.isEmpty else {
            throw DoubaoError.missingCredentials
        }
        
        // 建立 WebSocket 连接
        let url = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async")!
        var request = URLRequest(url: url)
        request.setValue(appId, forHTTPHeaderField: "X-App-Id")
        request.setValue(accessToken, forHTTPHeaderField: "X-Access-Token")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 发送初始化参数（具体格式需参考豆包官方文档）
        let initMessage: [String: Any] = [
            "sample_rate": 16000
        ]
        if let data = try? JSONSerialization.data(withJSONObject: initMessage) {
            webSocketTask?.send(.data(data)) { _ in }
        }
        
        // 开始接收消息
        receiveMessages()
        
        // 自己装 tap 发送音频
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            if let pcmData = self.convertToPCM16(buffer) {
                self.webSocketTask?.send(.data(pcmData)) { _ in }
            }
        }
    }
    
    func stop() {
        // 发送结束标记
        webSocketTask?.send(.string("{\"is_end\": true}")) { _ in }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            // 解析服务器返回的 JSON，提取 interim/final text
            // 回调 delegate
            // 继续接收下一条...
            self.receiveMessages()
        }
    }
    
    private func convertToPCM16(_ buffer: AVAudioPCMBuffer) -> Data? {
        // 将 buffer 转换为 PCM 16-bit, 16kHz
        // 具体实现待定
        return nil
    }
}

enum DoubaoError: Error {
    case missingCredentials
    case webSocketDisconnected
}
```

## 3. 配置系统

### SettingsManager 扩展

和现有配置保持同样风格：

```swift
class SettingsManager: ObservableObject {
    // 现有配置...
    
    @Published var selectedSpeechProvider: String {
        didSet {
            config["selectedSpeechProvider"] = selectedSpeechProvider
            saveConfig()
        }
    }
    
    // 豆包配置
    @Published var doubaoAppId: String {
        didSet { config["doubaoAppId"] = doubaoAppId; saveConfig() }
    }
    @Published var doubaoAccessToken: String {
        didSet { config["doubaoAccessToken"] = doubaoAccessToken; saveConfig() }
    }
    
    private init() {
        // 加载配置...
        self.selectedSpeechProvider = config["selectedSpeechProvider"] as? String ?? "apple"
        self.doubaoAppId = config["doubaoAppId"] as? String ?? ""
        self.doubaoAccessToken = config["doubaoAccessToken"] as? String ?? ""
    }
}
```

## 4. 设置界面

### 4.1 新增 Speech 选项卡

```swift
enum SettingsTab: String, CaseIterable {
    case general, speech, api
    
    var title: String {
        switch self {
        case .general: return localized("settings.tab.general")
        case .speech: return localized("settings.tab.speech")
        case .api: return localized("settings.tab.api")
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .speech: return "waveform"
        case .api: return "network"
        }
    }
}
```

### 4.2 SpeechSettingsView

```swift
struct SpeechSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localized("speech.title"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 引擎选择
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localized("speech.engine.title"))
                            .font(.system(size: 13, weight: .medium))
                        
                        Picker("", selection: $settings.selectedSpeechProvider) {
                            Text("Apple Speech").tag("apple")
                            Text("豆包 (ByteDance)").tag("doubao")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(14)
                }
                
                // 豆包配置（仅在选中豆包时显示）
                if settings.selectedSpeechProvider == "doubao" {
                    card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("豆包语音识别配置")
                                .font(.system(size: 13, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App ID")
                                    .font(.system(size: 12))
                                TextField("", text: $settings.doubaoAppId)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Access Token")
                                    .font(.system(size: 12))
                                SecureField("", text: $settings.doubaoAccessToken)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(14)
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
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
    }
}
```

## 5. 实现顺序

### Phase 1：提取 AppleSpeechProvider
- [ ] 定义 `SpeechRecognitionProvider` 协议
- [ ] 创建 `AppleSpeechProvider`，把现有 `SpeechManager` 中的 `SFSpeechRecognizer` 逻辑搬过去
- [ ] 修改 `SpeechManager`，用 Provider 替换直接调用
- [ ] 验证：按住 Fn 说话，Apple Speech 正常转写，HUD 显示正常

### Phase 2：添加豆包 Provider
- [ ] 在 `SettingsManager` 中添加 `selectedSpeechProvider`、`doubaoAppId`、`doubaoAccessToken`
- [ ] 实现 `DoubaoProvider`（WebSocket 连接、音频发送、结果接收）
- [ ] 实现 PCM 16-bit 格式转换
- [ ] 添加 SpeechSettingsView
- [ ] 验证：选择豆包，填入凭证，按住 Fn 说话，能看到实时转写结果

### Phase 3：后续扩展（以后再做）
- 通义 Provider
- Whisper Provider（复用 AudioRecorderManager 的 m4a 文件）
- MLX 本地模型

## 6. 技术风险

1. **WebSocket 接口未验证**：豆包的 WebSocket 消息格式、认证方式来自公开资料参考，实现前需查官方文档确认
2. **音频格式转换**：Apple Speech 的 buffer 格式和豆包要求的 PCM 16-bit 16kHz 可能不同，需要测试转换逻辑
3. **Tap 冲突**：AppleSpeechProvider 和 DoubaoProvider 都在 inputNode 上装 tap，但同一时间只有一个 Provider 在运行，不会冲突
