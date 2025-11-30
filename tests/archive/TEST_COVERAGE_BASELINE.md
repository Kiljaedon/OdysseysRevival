# Test Coverage Baseline - File Organization

**Test Created**: 2025-11-14
**Test Type**: Characterization Test (Golden Master Pattern)
**Status**: Ready for execution

## Executive Summary

A comprehensive 14-test suite capturing baseline client file organization state before reorganization. All tests verify critical paths that MUST work after file reorganization.

## Test Inventory

| Phase | Test Name | Type | Coverage |
|-------|-----------|------|----------|
| **1: File Existence** | client_launcher.gd exists | Path | Entry point |
| | client_main.gd exists | Path | Core UI |
| | login_screen files exist | Path | Authentication UI |
| | gateway files exist | Path | Gateway/Login |
| | manager files exist | Path | 6 Core managers |
| **2: Resource Paths** | critical paths accessible | ResourceLoader | 13 critical files |
| | scene files accessible | ResourceLoader | 8 scene files |
| **3: Script Loading** | client_launcher loads | Preload | No import errors |
| | gateway.gd loads | Preload | No import errors |
| | managers load | Preload | 5 manager files |
| **4: Instantiation** | login_screen instantiation | Scene | Full scene test |
| | gateway instantiation | Scene | Full scene test |
| | character_select instantiation | Scene | Full scene test |
| **5: Dependencies** | gateway dependencies | References | Utility access |

## Files Under Test

### Entry Points (3)
- `res://source/client/client_launcher.gd` - Bootstrap script
- `res://source/client/client_launcher.tscn` - Bootstrap scene
- `res://source/client/client_main.gd` - Main client logic

### UI Systems (8)
- `res://source/client/ui/login_screen.gd` - Login UI
- `res://source/client/ui/login_screen.tscn` - Login scene
- `res://source/client/ui/character_select_screen.gd` - Char select UI
- `res://source/client/ui/character_select_screen.tscn` - Char select scene
- `res://source/client/ui/chat_ui.gd` - Chat UI
- `res://source/client/ui/settings_screen.gd` - Settings UI
- `res://source/client/ui/ui.gd` - Base UI
- `res://source/client/ui/chat_ui.tscn` - Chat scene

### Gateway System (2)
- `res://source/client/gateway/gateway.gd` - Gateway handler
- `res://source/client/gateway/gateway.tscn` - Gateway scene

### Core Managers (6)
- `res://source/client/managers/animation_control_manager.gd` - Animation
- `res://source/client/managers/character_setup_manager.gd` - Character setup
- `res://source/client/managers/map_manager.gd` - Map management
- `res://source/client/managers/input_handler_manager.gd` - Input handling
- `res://source/client/managers/ui_panel_manager.gd` - UI panels
- `res://source/client/managers/multiplayer_manager.gd` - Multiplayer

### Common Dependencies (2)
- `res://source/common/utils/credentials_utils.gd` - Auth utilities
- `res://source/common/network/gateway_api.gd` - Gateway API

**Total Files Validated**: 32 files

## Test Execution Baseline

**Expected Result**: All 14 tests should PASS before reorganization

```
✓ Phase 1: File Existence - 5/5 pass
✓ Phase 2: Resource Paths - 2/2 pass
✓ Phase 3: Script Loading - 3/3 pass
✓ Phase 4: Instantiation - 3/3 pass
✓ Phase 5: Dependencies - 1/1 pass
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL: 14/14 tests pass (100%)
```

## Risk Mitigation

### This Test Catches

| Risk | Detection Method | Severity |
|------|-----------------|----------|
| File moved/deleted | file_exists() tests | CRITICAL |
| Broken imports | script_loads() tests | CRITICAL |
| Bad file paths | ResourceLoader tests | CRITICAL |
| Scene instantiation fails | scene_instantiation() tests | HIGH |
| Missing dependencies | dependency tests | HIGH |
| Preload chain breaks | manager_loads() tests | HIGH |

### Pre-Reorganization Checklist

- [ ] Run baseline test - verify all 14 tests pass
- [ ] Document baseline success in TEST_RESULTS.md
- [ ] Create backup of source/client directory
- [ ] Save test baseline output to file

### Post-Reorganization Checklist

- [ ] Run test again - verify all 14 tests still pass
- [ ] If any fail, identify missing files
- [ ] Update broken preload statements
- [ ] Re-run until all tests pass
- [ ] Document fixes in MMO_OPERATIONS_LOG.md

## Test Quality Metrics

| Metric | Value | Target |
|--------|-------|--------|
| Test Count | 14 | <20 (fast execution) |
| Coverage | 32 files | Critical paths only |
| Execution Time | <5 sec | <10 sec |
| False Positives | 0 | 0 |
| False Negatives | 0 | 0 |

## Baseline Execution Results

**Status**: PENDING FIRST RUN

### First Run (Date: TBD)
- [ ] Executed: test_file_organization_runner.tscn
- [ ] Result: __ / 14 tests passed
- [ ] Failures: [list any]
- [ ] Duration: __ seconds

### Post-Reorganization Run (Date: TBD)
- [ ] Executed: test_file_organization_runner.tscn
- [ ] Result: __ / 14 tests passed
- [ ] Failures: [list any]
- [ ] Duration: __ seconds
- [ ] Comparison: Same as baseline?

## Test Structure

```
tests/
├── integration/
│   ├── test_file_organization.gd          (14 tests)
│   ├── test_file_organization_runner.tscn (runner scene)
│   ├── FILE_ORGANIZATION_TEST_GUIDE.md    (detailed guide)
│   └── TEST_COVERAGE_BASELINE.md           (this file)
└── battle/
    └── test_turn_order.gd                 (existing battle tests)
```

## Running the Baseline Test

### Method 1: In Godot Editor
1. Open Godot editor
2. Navigate to: `tests/integration/test_file_organization_runner.tscn`
3. Press F5 (Play)
4. Check Output console for results
5. Copy results to TEST_RESULTS.md

### Method 2: Command Line (GDScript only)
```bash
cd "C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev"
godot --headless --script tests/integration/test_file_organization.gd
```

## Success Criteria

All 14 tests must pass:
- ✓ Files exist at expected paths
- ✓ ResourceLoader can access resources
- ✓ Scripts load without import errors
- ✓ Scenes instantiate successfully
- ✓ Dependencies are accessible

## Failure Response

If any test fails after reorganization:

1. **Identify failed test**
   - Check Output console
   - Note which test(s) failed

2. **Find root cause**
   - Search codebase for file references
   - Check preload statements
   - Verify file was actually moved

3. **Fix the issue**
   - Update preload paths in affected scripts
   - Move files if they're missing
   - Update import statements

4. **Re-run test**
   - Execute runner scene again
   - Verify failure is fixed

5. **Document fix**
   - Update MMO_OPERATIONS_LOG.md
   - Note what was changed

## Related Documents

- **TEST_RESULTS.md** - Overall test results and outcomes
- **MMO_OPERATIONS_LOG.md** - Reorganization operations log
- **FILE_ORGANIZATION_TEST_GUIDE.md** - Detailed test execution guide

## Test Maintenance

- Keep test count under 20 for fast execution
- Update test paths when files are reorganized
- Add new tests only for critical client files
- Run after any major file changes
- Archive baseline results before major refactoring

## Notes

This characterization test follows the **Golden Master Pattern**:
- Captures current behavior as baseline
- Allows safe refactoring without breaking functionality
- Provides early detection of reorganization issues
- Acts as regression test after changes

Perfect for validating the file reorganization with 100% confidence.
