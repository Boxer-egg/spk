# Core Updates - 2026-04-02 (Batch 3)

## 1. HUD Layout & Padding Fix
- **Vertical Buffer:** Increased internal padding (`.padding(.vertical, 20)`) and text area buffer (`.padding(.vertical, 8)`) to prevent recognition text from touching the top/bottom edges.
- **Improved Spacing:** Adjusted horizontal padding to 28px for better visual balance in the capsule.

## 2. Comprehensive Shortcut Customization
- **New Tab:** Added a "Shortcuts" tab in Settings with a dedicated keyboard icon.
- **Trigger Keys:** Users can now choose between:
  - `Fn` (Default)
  - `Double Left Ctrl`
  - `Double Left Option`
  - `Double Right Option`
- **Interaction Modes:** 
  - **Hold to Speak:** Press and hold to record, release to process.
  - **Click to Toggle:** Click once to start, click again to stop and process.

## 3. Settings UI Overhaul
- **Tab Icons:** Added SF Symbols to all tabs:
  - `network` -> API Settings
  - `text.bubble.fill` -> AI Prompt
  - `keyboard.fill` -> Shortcuts
- **Refined Layout:** Better spacing and clear usage hints for each shortcut mode.

## 4. Technical Improvements
- **Keyboard Engine:** Upgraded `KeyboardManager` to handle double-tap detection and state toggling.
- **State Management:** Added `isRecording` tracking in `AppDelegate` to support the toggle interaction mode.
