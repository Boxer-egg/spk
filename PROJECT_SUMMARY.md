# Project Memory: spk (macOS Voice Input App)

## Overview
**spk** is a professional-grade macOS menu bar application that provides real-time voice transcription with AI-powered refinement. It is built for macOS 14.0+.

## Tech Stack
- **Language:** Swift 5.9
- **UI Frameworks:** SwiftUI (HUD and Settings), AppKit (Lifecycle and Panels).
- **Core Frameworks:** 
  - `Speech`: For on-device real-time transcription.
  - `AVFoundation`: For audio input and volume monitoring.
  - `CoreGraphics`: For global shortcut detection via `CGEventTap`.
  - `Combine`: For reactive state synchronization.

## Architecture
- **App/AppDelegate.swift:** Entry point and coordinator. Manages the menu bar and windows.
- **Managers:**
  - `SettingsManager`: Centralized `ObservableObject` for all persistent settings.
  - `KeyboardManager`: Low-level global key listener (Fn, Ctrl, Option).
  - `SpeechManager`: Manages `AVAudioEngine` and `SFSpeechRecognizer`.
  - `LLMManager`: Handles OpenAI-compatible API calls for text refinement.
  - `ClipboardManager`: Manages text injection and `Cmd+V` simulation.
- **Models/HUDViewModel.swift:** Reactive state for the floating HUD.
- **UI Components:**
  - `HUDPanel`: Transparent `NSPanel` for the floating UI.
  - `HUDView`: Dynamic, multiline-capable capsule with status indicators.
  - `SettingsView`: 4-tab configuration interface (General, API, Prompt, Shortcuts).

## Key Features & Logic
- **Shortcuts:** Supports single-key triggers (Fn, Left Ctrl, Left Option, Right Option).
- **Interaction Modes:** Toggle between "Hold to Speak" and "Click to Toggle".
- **AI Refinement:** Optional LLM processing with customizable System Prompts.
- **Real-time Sync:** Bidirectional state synchronization between Settings and Menu Bar.

## Build & Release
- **Build System:** SPM + Makefile.
- **Packaging:** `make` generates a signed `spk.app` bundle with necessary entitlements for Sandbox/Permissions.
- **Security:** No hardcoded secrets. All sensitive data is stored in local `UserDefaults`.

## Project History
- **Initial:** Project "koe" (renamed to "spk").
- **Batch 2-3:** Added multi-line HUD, waveform animations, and tabbed settings.
- **Batch 4 (Final):** Simplified shortcuts, refined HUD status area, and implemented full state synchronization.
