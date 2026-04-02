# Core Updates - 2026-04-02 (Batch 2)

## 1. Multi-line Elastic HUD
- **Dynamic Sizing:** The HUD capsule now expands vertically to accommodate long speech recognition results.
- **Improved Layout:** Switched from a fixed capsule to a continuous-style `RoundedRectangle` with dynamic height (min 56px).
- **Text Wrapping:** Removed line limits to ensure full visibility of transcribed text.

## 2. Tabbed Settings Interface
- **Enhanced Organization:** Replaced the single-form layout with a `TabView` to separate "API Settings" and "AI Prompt".
- **Larger Footprint:** Increased the Settings window size to 550x450 for a more comfortable editing experience.
- **Dedicated Editor:** The System Prompt now has a much larger `TextEditor` area in its own tab.

## 3. Waveform Animation Improvements
- **Increased Amplitude:** Boosted the movement range of the 5-bar waveform for more dramatic visual feedback.
- **Smoother Dynamics:** Tweaked the spring animation parameters for snappier audio-reactive movement.

## 4. UI/UX Tweaks
- **Vertical Alignment:** Centered waveform/status icons vertically alongside multi-line text.
- **Persistent Save:** Added a global bottom bar for the "Save All Settings" button across all tabs.
