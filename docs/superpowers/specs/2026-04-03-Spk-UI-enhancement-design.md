# Spk UI 增强设计文档

## 1. 目标

修复并优化 Spk 的两个用户界面问题：
1. **History 菜单过长**：当转录文字较多时，菜单项会横向占满整个屏幕，影响可用性。
2. **Settings 页面简陋**：现有的 TabView + 简单 Form 布局视觉层次弱，需要升级为更现代的 Sidebar 分栏布局。

## 2. History 菜单截断

### 2.1 现状
`AppDelegate.updateHistoryMenu()` 直接将完整文本拼接为菜单标题：
```swift
let title = "\(dateStr): \(entry.refinedText ?? entry.originalText)"
```
长文本会导致菜单项极宽。

### 2.2 设计方案
- **限制单行长度**：将每行标题限制为 **50 个字符**（兼顾中英文，约"巴掌大"宽度）。
- **截断方式**：超出部分以 `"..."` 替代，保留时间前缀以便用户识别。
- **实现逻辑**：在构建 `title` 时先计算总长度，若超过 50 则对文本部分进行截断。

```swift
let prefix = "\(dateStr): "
let text = entry.refinedText ?? entry.originalText
let maxChars = 50
let title: String
if prefix.count + text.count > maxChars {
    let remain = maxChars - prefix.count - 3
    title = prefix + String(text.prefix(max(0, remain))) + "..."
} else {
    title = prefix + text
}
```

### 2.3 清除历史记录
在 History 子菜单底部增加操作项：
- 当历史记录不为空时，在最后一项后添加 `NSMenuItem.separator()` 和 `"Clear History..."` 菜单项。
- 点击后弹出 `NSAlert` 二次确认："确定要清除所有历史记录吗？此操作无法撤销。"
- 确认后调用 `HistoryManager.shared.clearAll()`（需新增方法）并刷新菜单。

## 3. Settings 页面重构

### 3.1 布局方案：Sidebar 分栏

将现有的 `TabView` 改为 **左侧 Sidebar + 右侧内容区** 的自定义布局（不使用 `NavigationSplitView` 以避免 macOS 版本兼容和动画问题）。

- **窗口尺寸**：从 `550 × 450` 调整为 **`640 × 420`**。
- **左侧 Sidebar**：宽度 `160px`，包含 4 个导航项：
  - General（`gearshape.fill`）
  - API Settings（`network`）
  - AI Prompt（`text.bubble.fill`）
  - Shortcuts（`keyboard.fill`）
- **右侧内容区**：根据 `selectedTab` 显示对应子视图。
- **适配浅色/深色模式**：全部使用系统动态颜色，不硬编码。

### 3.2 Sidebar 样式（深色/浅色通用）

```swift
// 选中背景
.background(
    selectedTab == tab
        ? Color(nsColor: .selectedContentBackgroundColor)
        : Color.clear
)
.foregroundColor(selectedTab == tab ? .primary : .secondary)
.cornerRadius(6)
```

- 选中项使用系统高亮色背景（深色下偏灰蓝，浅色下偏蓝灰）。
- 未选中项文字使用 `.secondary`，hover 时轻微提亮。

### 3.3 内容区卡片样式

右侧内容采用分组卡片：
- 每个大分组（如 Core Features、Endpoint Configuration）用一个圆角卡片包裹。
- 卡片背景：`.background(Color(nsColor: .controlBackgroundColor))`。
- 卡片内设置项之间用细线 `Divider` 或 `overlay(Rectangle().frame(height: 1))` 分隔。
- 每个设置项结构：左侧标题 + 说明（纵向），右侧是 Toggle / Picker / TextField。

### 3.4 子视图拆分

将 `SettingsView` 拆分为 5 个文件：
- `SettingsView.swift`：主容器，负责窗口、Sidebar、Tab 路由。
- `GeneralSettingsView.swift`：LLM、Clipboard、History 开关。
- `APISettingsView.swift`：Base URL、API Key、Model、Test Connection 小组件。
- `PromptSettingsView.swift`：System Prompt 编辑器。
- `ShortcutSettingsView.swift`：Hold to Speak、Trigger Key、Usage Hints。

## 4. API Test Connection 小组件

### 4.1 现状
目前仅有一个 Button + ProgressView + 简单的 Text 状态，视觉弱。

### 4.2 新设计
将测试区域改为**状态卡片**组件：

```
┌─────────────────────────────────┐
│ [Test Connection]  (loading 时转圈) │
├─────────────────────────────────┤
│ 默认：                          │
│   点击上方按钮测试连接状态      │
│                                 │
│ 成功：                          │
│   ✓ 连接成功（耗时 1.23s）      │
│                                 │
│ 失败：                          │
│   ✗ Error: Unauthorized         │
└─────────────────────────────────┘
```

### 4.3 交互细节
- **按钮**：`Label("Test Connection", systemImage: "bolt.horizontal.fill")`。
- **加载态**：按钮 disabled，右侧显示 `ProgressView` + "Testing..." 灰字。
- **计时逻辑**：点击时记录 `Date()`，回调成功/失败时计算 `Date().timeIntervalSince(start)`，保留两位小数显示在结果文本中。
- **状态卡片**：根据 `testStatus` 切换边框颜色（默认 `.secondary`、成功 `.green`、失败 `.red`），用 SF Symbol 图标前缀增强可读性。

### 4.4 代码示意
```swift
@State private var testDuration: TimeInterval = 0

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
```

显示模板：
- 成功：`"✓ \(testStatus)（耗时 %.2fs）".localizedFormat(testDuration)`
- 失败：`"✗ \(testStatus)（耗时 %.2fs）".localizedFormat(testDuration)`

## 5. 文件变更清单

| 文件 | 变更 |
|------|------|
| `AppDelegate.swift` | History title 截断逻辑、Clear History 菜单项 |
| `Managers/HistoryManager.swift` | 新增 `clearAll()` 方法 |
| `UI/SettingsView.swift` | 重构为 Sidebar 主容器 |
| `UI/GeneralSettingsView.swift` | 新增 |
| `UI/APISettingsView.swift` | 新增，含 Test Connection 状态卡片 |
| `UI/PromptSettingsView.swift` | 新增 |
| `UI/ShortcutSettingsView.swift` | 新增 |

## 6. 不在本次范围

- 不修改数据模型结构（`HistoryEntry` 不变）。
- 不修改 LLM 请求逻辑。
- 不新增设置项，仅优化现有项的排版和交互。
