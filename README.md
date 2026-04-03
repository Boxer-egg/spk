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

**构建**
```bash
git clone https://github.com/Boxer-egg/spk.git
cd spk
make build
```

**安装**
直接安装app即可


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
