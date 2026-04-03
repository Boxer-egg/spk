# Spk

macOS 菜单栏语音输入工具 · 按住 Fn 键即可录音

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## 功能简介

- 按住 `Fn` 键开始录音，松开后自动将转录文字注入当前输入框
- 使用 Apple 原生 Speech Recognition，支持中文（zh-CN）、英文等多语言
- 悬浮 HUD 实时显示录音状态与转录内容
- 可选接入 OpenAI 兼容接口对文字进行 LLM 精炼
- 纯菜单栏应用，不占 Dock，轻量常驻

## 快速开始

### 从源码构建

```bash
git clone https://github.com/Boxer-egg/spk.git
cd spk
make all
```

构建完成后，当前目录会出现 `Spk.app`，直接拖到「应用程序」文件夹即可。

### 下载预编译版本

前往 [Releases](https://github.com/Boxer-egg/spk/releases) 下载最新版 `Spk.zip`，解压后将 `Spk.app` 拖入「应用程序」文件夹。

> **注意：** 由于本应用使用 Ad-hoc 自签名，从浏览器下载后首次打开会被 macOS Gatekeeper 拦截。你可以选择以下任一方式解决：
>
> 1. **右键打开**：在「启动台」或「应用程序」文件夹中，按住 `Control` 键并点击 `Spk` → 选择「打开」→ 点击弹窗中的「仍要打开」。
> 2. **终端移除隔离属性**（推荐）：
>    ```bash
>    sudo xattr -rd com.apple.quarantine /Applications/Spk.app
>    ```

## 权限要求

首次启动需授权以下系统权限：

- 麦克风（录音）
- 语音识别
- 辅助功能（`Fn` 键全局监听）

## 配置

点击菜单栏图标进入设置，可配置：

- 识别语言：zh-CN / en-US / zh-TW / ja-JP / ko-KR
- LLM 精炼接口（OpenAI 兼容，可留空跳过）

---

## 致谢

- 提示词来源：[yetone/voice-input-src](https://github.com/yetone/voice-input-src)
- 提示词由 Claude 优化
- 代码由 Gemini CLI 生成
