# Implementation Plan: Client-Side Prediction

## Phase 1: Shared Data Structures & Packet Encoding

### 1.1. Packet Encoder Update (`source/common/network/packet_encoder.gd`)
- [ ] **Modify `build_player_input_packet`:** Ensure the `sequence` (u16) is correctly packed.
- [ ] **Modify `parse_player_input_packet`:** Ensure `sequence` is correctly parsed.
- [ ] **Create `build_prediction_ack_packet`:** Create a new binary packet type `PREDICTION_ACK` (0x05).
    -   Format: `[Type:u8, PeerID:u16, LastSequence:u16, PosX:f32, PosY:f32]`
    -   (Using PeerID allowing piggybacking or direct addressing).
- [ ] **Create `parse_prediction_ack_packet`:** Parser for the above.

### 1.2. Packet Types (`source/common/network/packet_types.gd`)
- [ ] Add `PREDICTION_ACK = 0x05`.

## Phase 2: Client-Side Prediction (Input)

### 2.1. InputHandlerManager (`source/client/managers/input_handler_manager.gd`)
- [ ] Add `prediction_history: Array`.
- [ ] Add `current_sequence: int`.
- [ ] **Update `process_movement(delta)`:**
    -   Increment `current_sequence`.
    -   Capture input.
    -   **PREDICT:** Apply velocity to `test_character.velocity` and call `move_and_slide()` *immediately*.
    -   **RECORD:** Push `{seq: current_sequence, pos: position, input: input_vector}` to `prediction_history`.
    -   **SEND:** Send input packet with `current_sequence` via `MultiplayerManager`.

### 2.2. Multiplayer Manager (`source/client/managers/multiplayer_manager.gd`)
- [ ] Update `update_multiplayer_position` to accept sequence number from `InputHandlerManager`?
    -   *Refactor:* `InputHandlerManager` should probably generate the packet, or return the sequence to `MultiplayerManager`.
    -   *Better:* `InputHandlerManager` handles the logic, `MultiplayerManager` just provides the socket.

## Phase 3: Server-Side Processing

### 3.1. InputManager (`source/server/managers/input_manager.gd`)
- [ ] Update `handle_binary_input`:
    -   Extract `sequence`.
    -   Store `last_processed_sequence` in `player_manager.connected_players[peer_id]`.
    -   Perform movement validation (Physics checks).
    -   Update `player_positions`.

### 3.2. WorldNetworkService (`source/common/network/services/world_network_service.gd`)
- [ ] **New Method:** `send_prediction_ack(peer_id, sequence, position)`.
    -   Calls `binary_ack` RPC (or similar).
    -   Ideally, we send this *every tick* or *every time we process input*.

### 3.3. Server Loop
- [ ] In `ServerWorld._physics_process` or `InputManager.apply_movement`:
    -   After applying movement, immediately send `PREDICTION_ACK` to the specific client.
    -   (This ensures low latency feedback loop).

## Phase 4: Client Reconciliation

### 4.1. Multiplayer Manager (`source/client/managers/multiplayer_manager.gd`)
- [ ] **New Handler:** `handle_binary_ack(packet)`.
    -   Parse `PREDICTION_ACK`.
    -   Extract `server_sequence` and `server_position`.
    -   **RECONCILE:**
        -   Find state in `InputHandlerManager.prediction_history` matching `server_sequence`.
        -   If not found (too old), ignore (or snap if very new).
        -   Compare `server_position` with `history.position`.
        -   If `distance > threshold` (e.g. 2.0 pixels):
            -   **Snap:** `test_character.position = server_position`.
            -   **Replay:** Loop through `prediction_history` from `server_sequence + 1` to end.
                -   Re-apply inputs.
                -   Re-run `move_and_slide()`.
                -   Update positions in history.

## Phase 5: Verification & Cleanup
- [ ] Add `DebugConsole` commands to toggle prediction.
- [ ] Add simulated lag (using `NetworkServer` latency simulation if available, or custom delay) to verify smoothness.
