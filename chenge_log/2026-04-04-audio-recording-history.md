# Core Updates - 2026-04-04

## 1. Audio Recording History (Optional)
- **On-Demand Recording:** Spk can now save an m4a (AAC) audio file alongside each transcription, starting and stopping automatically with the hotkey recording session.
- **Storage Location:** Audio files are stored in `~/Library/Application Support/spk/tape/`.
- **Automatic Cleanup:** Orphaned `.m4a` files are removed on app startup, and audio files are deleted automatically when history entries rotate beyond the 20-entry limit or when history is cleared.
- **Path Safety:** Filenames are sanitized using `lastPathComponent` to prevent path traversal.

## 2. Settings UI Redesign
- **Grouped History Controls:** Replaced the single "Record History" toggle with a dedicated card section:
  - **Save Text Record:** Always active, shown as a disabled toggle for clarity.
  - **Save Audio Record:** User-toggleable switch (default off), bound to `isHistoryAudioEnabled`.
- **Default Behavior:** Audio saving is opt-in and off by default; no changes to existing transcription-only workflow.

## 3. Menu-Bar History Enhancements
- **Open Original Audio:** Each history entry submenu now includes a third action — "打开原始音频" / "Open Original Audio" — which opens the associated m4a in the default player (e.g., QuickTime).
- **Smart Disabling:** If an entry has no audio file, the menu item is automatically grayed out.

## 4. Technical Additions
- **AudioRecorderManager:** New singleton wrapping `AVAudioRecorder` for m4a/AAC output, with double-start guards and error-path file cleanup.
- **HistoryEntry Extension:** Added `audioFilename` field to link each transcript to its corresponding tape file.
- **SettingsManager:** Added `isHistoryAudioEnabled` boolean with YAML persistence and migration support.
- **Localization:** New strings localized across all 6 supported languages (en, zh-Hans, ja, de, fr, es).
