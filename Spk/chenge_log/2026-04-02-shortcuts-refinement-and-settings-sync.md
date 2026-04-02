# Core Updates - 2026-04-02 (Batch 4)

## 1. Simplified Shortcuts
- **Single-Key Trigger:** Replaced double-tap logic with direct single-key triggers for better reliability.
- **Key Options:** Users can now choose from: `Fn`, `Left Ctrl`, `Left Option`, `Right Option`.
- **Interaction Logic:** Maintained support for both "Hold to Speak" and "Click to Toggle" modes.

## 2. HUD Status Refinement
- **Consolidated Indicator:** Moved the "Refining..." text to the leading status area, grouping it directly with the loading spinner.
- **Fixed Layout:** Ensured the status area has a fixed width (60px) so that long recognition text never obscures the processing state.
- **Icon Alignment:** Centered all status icons (waveform, spinner, checkmark) within the leading column.

## 3. Settings UI & Sync
- **Iconic Tabs:** Added SF Symbols to every tab for better visualization:
  - `gearshape.fill` -> General
  - `network` -> API Settings
  - `text.bubble.fill` -> AI Prompt
  - `keyboard.fill` -> Shortcuts
- **Real-time Sync:** Converted `SettingsManager` to an `ObservableObject`. Changing the LLM toggle in the Settings window now instantly updates the menu bar checkmark, and vice versa.
- **Dedicated General Tab:** Moved the core "Enable LLM Correction" toggle to a new "General" tab.

## 4. Technical Improvements
- **Refactored Data Flow:** Centralized all persistence in `SettingsManager` using `@Published` properties for seamless state propagation.
- **Improved Menu Handling:** Added `updateMenuStates()` in `AppDelegate` to maintain consistency across the UI.
