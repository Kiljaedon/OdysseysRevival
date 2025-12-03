# Refactoring Plan: DevClientController Cleanup

## Phase 1: Analysis & Preparation
*   [ ] **Analyze Wrappers**: Scan `dev_client_controller.gd` and list all functions that are pure delegates to a manager.
*   [ ] **Verify Access**: Ensure `map_manager`, `multiplayer_manager`, `input_handler`, `chat_manager`, `ui_manager` are public variables.

## Phase 2: Refactoring (Iterative)
*   [ ] **Refactor Map Wrappers**:
    *   Find callers of `spawn_player`, `despawn_player`, `load_map`.
    *   Update them to use `controller.map_manager.*`.
    *   Delete wrappers.
*   [ ] **Refactor Multiplayer Wrappers**:
    *   Find callers of `sync_positions`, `handle_binary_positions`.
    *   Update to `controller.multiplayer_manager.*`.
    *   Delete wrappers.
*   [ ] **Refactor Chat/UI Wrappers**:
    *   Find callers of `handle_chat`, `toggle_ui`.
    *   Update to `controller.chat_manager.*` or `controller.ui_manager.*`.
    *   Delete wrappers.

## Phase 3: Verification
*   [ ] **Static Analysis**: Run Godot's script check (via headless run) to catch broken references.
*   [ ] **Manual Test**:
    *   Login and spawn (Map/Multiplayer check).
    *   Send a chat message (Chat check).
