# Core Updates - 2026-04-02

## 1. HUD Real-time Feedback & Status Management
- **Issue Fixed:** Resolved the bug where the HUD remained blank during recording (Demand #3).
- **Real-time Echo:** Implemented live transcription display within the HUD while the user is speaking (Demand #4).
- **Status Lifecycle:** Introduced a state machine (`listening` -> `refining` -> `success/error`) to provide clear visual cues for each stage.
- **AI Processing Visibility:** Added an "AI Refining..." indicator with a spinner and state text during LLM processing.

## 2. Visual & Animation Enhancements
- **Dynamic Waveform:** Improved the sensitivity and responsiveness of the 5-bar waveform animation based on real-time RMS volume (Demand #5).
- **Spring & Pulse FX:** Added spring transitions and breathing pulse effects to the HUD capsule for a more interactive feel.
- **Success Indicators:** Added checkmark and error icons to signal the completion of the process.

## 3. Settings & API Improvements
- **System Prompt Editing:** Added a `TextEditor` in the Settings view to allow users to customize the LLM's correction behavior (Demand #2).
- **Connection Testing:** Implemented a "Test Connection" button with real-time status messages (Demand #1).
- **API Feedback:** The test button now provides green "Success" or red "Error" messages based on the actual API response.

## 4. Technical Refactoring
- **Architecture:** Introduced `HUDViewModel` as an `ObservableObject` singleton to centralize UI state and ensure reactive updates across the app.
- **Permissions:** Added explicit checks and logging for Speech Recognition and Microphone access on startup.
- **Reliability:** Improved the Fn key detection logic to handle more complex keyboard flag states.
