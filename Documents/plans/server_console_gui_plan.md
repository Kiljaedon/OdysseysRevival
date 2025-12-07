# Server Console GUI Improvement Plan

## Objective
Implement a single-window Server GUI that correctly captures all startup logs and provides a dominant, readable console view, eliminating the need for the external Windows console window.

**Reference Spec:** `Documents/specs/server_console_gui_spec.md`

## Strategy
1.  **Fix Data Capture:** Modify `ui_manager.gd` to read the log file from the beginning of the current session, ensuring startup messages are not lost.
2.  **Redesign Layout:** Rebuild the UI layout to prioritize the console (70% height), moving admin controls to a footer or collapsible pane.
3.  **Hide External Console:** Once the GUI faithfully reproduces the console output, update the startup scripts to suppress the external console window.

## Implementation Phases

### Phase 1: Console Capture Repair
*   **Goal:** Ensure GUI console shows "Starting server..." and all subsequent logs.
*   **File:** `source/server/managers/ui_manager.gd`
*   **Task:**
    *   Modify `_setup_console_capture()` to locate the session start marker in the log file.
    *   Implement a buffer to replay messages captured before the UI node was ready.

### Phase 2: UI Layout Overhaul
*   **Goal:** Make the console readable and primary.
*   **File:** `source/server/managers/ui_manager.gd`
*   **Task:**
    *   Change root layout to a `VBoxContainer`.
    *   Top: Header (Status, Players, Uptime).
    *   Middle: Console Output (Expanded, Monospace Font 13px).
    *   Bottom: Admin Controls (TabContainer).

### Phase 3: Startup Script Adjustment (The "Hide" Step)
*   **Goal:** Launch without the black window.
*   **File:** `run_local_server.bat`
*   **Task:**
    *   Remove priority for `_console.exe`.
    *   Ensure standard executable is used.

## Verification Plan
*   **Automated Test:** `tests/test_server_gui_capture.gd`
    *   Simulate log file writing.
    *   Verify `ui_manager` captures lines written *before* it initialized.
*   **Manual Verification:**
    *   Launch server.
    *   Verify startup text appears in GUI.
    *   Verify no external black window appears.

## Todo List
1.  Create `tests/test_server_gui_capture.gd`.
2.  Refactor `source/server/managers/ui_manager.gd` (Capture logic).
3.  Refactor `source/server/managers/ui_manager.gd` (Layout).
4.  Modify `run_local_server.bat`.
