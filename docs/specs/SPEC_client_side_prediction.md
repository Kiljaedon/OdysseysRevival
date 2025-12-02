# Specification: Client-Side Prediction & Server Reconciliation

## 1. Overview
This specification defines the implementation of Client-Side Prediction and Server Reconciliation for "Odysseys Revival". The goal is to provide instant feedback to the player during movement while maintaining server authority to prevent cheating (speed hacks, teleportation).

## 2. Current Architecture (To Be Changed)
- **Client:** Sends input (UP/DOWN/LEFT/RIGHT) to Server via `binary_input`.
- **Server:** Calculates position, updates state, sends `sync_positions` via RPC.
- **Client:** Waits for `sync_positions` to update local player position.
- **Result:** High latency feel ("rubber banding" or delayed movement).

## 3. Proposed Architecture

### 3.1. Client-Side (Prediction)
1.  **Input Handling (`InputHandlerManager`):**
    -   Sample input every frame (or physics tick).
    -   Assign a monotonically increasing **Sequence Number (`input_sequence`)** to each input packet.
    -   Apply movement logic *immediately* to the local `CharacterBody2D`.
    -   Store the Input + Resulting Position + Sequence Number in a **History Buffer**.
    -   Send Input + Sequence Number to Server (Binary Packet).

2.  **Reconciliation (`MultiplayerManager`):**
    -   Receive `sync_positions` (or specific `ack_input` packet) from Server.
    -   Packet contains: `authoritative_position` and `last_processed_sequence`.
    -   **Check:** Does `authoritative_position` match the position stored in History for `last_processed_sequence`?
        -   **Match:** Discard history up to `last_processed_sequence`. Prediction was correct.
        -   **Mismatch:** 
            1.  Snap local player to `authoritative_position`.
            2.  **Replay** all inputs in History *after* `last_processed_sequence` to re-predict the current frame.

### 3.2. Server-Side (Authority)
1.  **Input Processing (`InputManager`):**
    -   Receive binary input packet (now includes `input_sequence`).
    -   Validate input (speed check, wall check).
    -   Update Server-side position.
    -   Store `last_processed_sequence` for that player.
2.  **State Broadcast (`WorldNetworkService`):**
    -   When sending `sync_positions` (or new `ack_packet`), include the `last_processed_sequence` for the target player.

## 4. Data Structures

### 4.1. Input Packet (Binary)
Current: `[Type:u8, Seq:u16, Flags:u8, Delta:u16]`
*   We are already sending `Seq` (Sequence), but are we using it?
*   Need to ensure `Seq` wraps correctly (u16 wraps at 65535).

### 4.2. Prediction History (Client)
```gdscript
class PredictionState:
    var sequence: int
    var position: Vector2
    var velocity: Vector2
    var input_flags: int
    var delta: float
```

## 5. Implementation Plan

### Phase 1: Client Prediction Logic
1.  Modify `InputHandlerManager.gd`:
    -   Add `prediction_history: Array`.
    -   In `process_movement()`, apply velocity immediately.
    -   Push state to `prediction_history`.

### Phase 2: Server Response Update
1.  Modify `InputManager.gd` (Server):
    -   Read `sequence` from packet.
    -   Store `last_sequence` in `connected_players` data.
2.  Modify `PacketEncoder.gd`:
    -   Update `build_player_position_packet` (or create new `build_ack_packet`) to include `last_sequence`.
    -   Ideally, piggyback this on `sync_positions`?
    -   *Constraint:* `sync_positions` is a Dictionary broadcast to everyone. It's inefficient to send everyone's sequence to everyone.
    -   *Solution:* Send a separate, lightweight "Prediction Ack" packet (Unreliable) to the *specific client* alongside the position update, OR include it in the specialized `player_data` if using binary.

### Phase 3: Client Reconciliation
1.  Modify `MultiplayerManager.gd`:
    -   Listen for the Ack/Position packet.
    -   Perform the Mismatch check.
    -   Trigger Replay if needed.

## 6. Constraints & Edge Cases
-   **Physics Ticks:** Client and Server must run movement on the same physics tick rate (e.g., 60hz) or use `delta` accurately.
-   **Collisions:** Client must have static collision map loaded to predict wall slides.
-   **Jitter:** Replaying 50 frames in one frame can cause visual jitter. Use a "visual object" (interpolated) separate from the "physics object" (snapped) if needed, but for 2D RPG, snapping is usually acceptable if mismatches are rare.

## 7. Verification
-   **Test 1:** Latency Simulation. Add 200ms fake lag. Player should move instantly.
-   **Test 2:** Correction. Modify server to block movement (e.g., invisible wall). Client should move into wall, then snap back.
