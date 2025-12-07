# Server Console GUI Improvement Specification

## Problem Statement

Currently the server runs with TWO windows:
1. **Windows Console** - Shows all print() output (the useful stuff)
2. **GUI Window** - Has a console panel that barely captures anything

The GUI console panel is broken because:
- It starts reading the log file from the END, missing all startup messages
- The layout gives too much space to admin panels, not enough to console
- Font is too small (11px)
- No way to see all the initialization output

## Goal

Single window server GUI where the console panel displays ALL output that currently shows in the Windows console.

---

## Proposed Changes

### 1. Fix Console Capture Mechanism

**Current behavior (broken):**
```gdscript
# Line 60-61 in ui_manager.gd
file.seek_end(0)  # Starts at END - misses everything!
_last_log_position = file.get_position()
```

**Proposed fix:**
- Find the session start marker `"=== ODYSSEYS REVIVAL - DEVELOPMENT SERVER ==="` in log file
- Read all content from that point forward
- Buffer early messages and replay when UI is ready

### 2. Redesign GUI Layout

**Current layout:**
```
┌─────────────────────────────────────────────────────────┐
│  LEFT (60%): Admin Panel    │  RIGHT (40%): Console     │
│  - Connection Info          │  [tiny console panel]     │
│  - Server Stats             │                           │
│  - Admin Utilities (tabs)   │                           │
└─────────────────────────────────────────────────────────┘
```

**Proposed layout:**
```
┌─────────────────────────────────────────────────────────┐
│ HEADER: Title | Status: RUNNING | Players: 0 | Uptime   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  CONSOLE OUTPUT (70% of screen height)                  │
│  [Large monospace terminal-style panel]                 │
│  - All server output with color coding                  │
│  - Line count indicator                                 │
│  - Clear button                                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ FOOTER: Collapsible admin panel (tabs)                  │
│ [Connection Info] [Server Stats] [Admin Tools]          │
└─────────────────────────────────────────────────────────┘
```

### 3. Console Panel Improvements

| Feature | Current | Proposed |
|---------|---------|----------|
| Font size | 11px | 13px |
| Font | Consolas | Consolas/Monospace |
| Position | Right side, cramped | Main area, dominant |
| Captures startup | No | Yes |
| Line count | No | Yes, in title bar |
| Scroll | Auto-follow | Auto-follow + manual scroll |

### 4. Hide Windows Console

After GUI console works properly:
- Add `_hide_windows_console()` function using PowerShell to call Windows API
- Call it at server startup in `server_world.gd`

---

## Files to Modify

1. **`source/server/managers/ui_manager.gd`** - Complete rewrite of UI layout and console capture
2. **`source/server/server_world.gd`** - Add call to hide Windows console (after GUI works)

---

## Implementation Steps

1. [ ] Rewrite `_setup_console_capture()` to read from session start
2. [ ] Rewrite `create_server_ui()` with console-dominant layout
3. [ ] Add line count display
4. [ ] Increase font size
5. [ ] Test that all startup messages appear
6. [ ] Add Windows console hiding function
7. [ ] Test single-window operation

---

## Questions for User

1. Do you want the admin panel at the BOTTOM (horizontal tabs) or RIGHT SIDE (vertical, collapsible)?
2. Should the console have a search/filter feature?
3. Any specific color preferences for different message types?

---

## Approval

- [ ] User approves this spec
- [ ] Proceed with implementation
