# Core Updates - 2026-04-02 (Final Batch)

## 1. Simplified Keyboard Logic
- **Pure Single-Key:** Removed all double-tap complexity. The trigger is now a direct single press of the chosen key.
- **Support Keys:** Full support for `Fn`, `Left Ctrl`, `Left Option`, and `Right Option`.
- **Flexible Interaction:** Works seamlessly with both "Hold to Speak" and "Toggle" modes.

## 2. HUD Visual Refinement
- **Consolidated Status:** Redesigned the leading area to stack the loading spinner and "Refining..." text vertically.
- **Better Visibility:** This ensures processing status is never obscured by the main text area, regardless of text length.
- **Dynamic Height:** The capsule height now scales even better (min 70px) to balance the new vertical status layout.

## 3. Advanced Settings & Sync
- **Tabbed Architecture:** Four distinct tabs with SF Symbols:
  - `gearshape.fill` (General): Manage LLM master switch.
  - `network` (API Settings): Configure endpoints and keys.
  - `text.bubble.fill` (AI Prompt): Large editor for refinement logic.
  - `keyboard.fill` (Shortcuts): Single-select trigger keys and interaction modes.
- **Bi-directional Sync:** Settings window and Menu Bar stay in perfect sync using a centralized `ObservableObject`.

## 4. Security & GitHub Readiness
- **Zero-Secret Policy:** Confirmed no API keys are hardcoded; all sensitive data stays in local `UserDefaults`.
- **Git Hygiene:** Added `.gitignore` and purged binary artifacts from history to ensure a clean public repository.
