# File Organization Characterization Test Suite

**Test Type:** Golden Master (Characterization) Test
**Purpose:** Capture baseline client behavior before file reorganization
**Status:** READY FOR EXECUTION
**Created:** 2025-11-14

---

## Quick Start

### To Run Tests

1. Open Godot editor
2. Navigate to: `res://tests/integration/test_file_organization_runner.tscn`
3. Press **F5** to run
4. Check **Output** tab for results
5. Expected: **14/14 PASS**

### What Gets Tested

- 32 critical client files across 5 validation phases
- Entry points, UI screens, gateway, managers, utilities
- File accessibility, preload chain integrity, scene instantiation

---

## Test Suite Contents

### Main Test File
**`test_file_organization.gd`** (420 lines)
- 14 characterization tests
- 5 validation phases
- Helper functions for safe loading

### Test Runner
**`test_file_organization_runner.tscn`**
- Scene that executes the test suite
- Run with F5 in Godot editor

### Documentation
1. **`FILE_ORGANIZATION_TEST_GUIDE.md`** - Detailed test execution guide
2. **`TEST_COVERAGE_BASELINE.md`** - Coverage inventory and risk matrix
3. **`CHARACTERIZATION_TEST_README.md`** - This file

### External Documentation
1. **`C:\Users\dougd\GoldenSunMMO\Documents\TEST_RESULTS.md`** - Test results log
2. **`C:\Users\dougd\GoldenSunMMO\Documents\MMO_OPERATIONS_LOG.md`** - Operations log

---

## Test Structure

### Phase 1: Core Files Existence (5 tests)
Verify all critical files exist at expected paths
- client_launcher.gd, client_main.gd
- login_screen (UI)
- gateway (UI + API)
- managers (6 files)

### Phase 2: Resource Path Validation (2 tests)
Use ResourceLoader to verify Godot can access paths
- 13 critical script/scene paths
- 8 scene files specifically

### Phase 3: Script Loading (3 tests)
Load scripts to catch preload chain breakage
- launcher script
- gateway script
- manager scripts (5 total)

### Phase 4: Scene Instantiation (3 tests)
Load and instantiate actual scenes
- login_screen
- gateway
- character_select

### Phase 5: Dependencies (1 test)
Verify gateway.gd can reference required utilities
- credentials_utils
- gateway_api

---

## Files Validated (32 Total)

| Category | Count | Files |
|----------|-------|-------|
| Entry Points | 3 | client_launcher, client_main |
| UI Systems | 8 | login_screen, char_select, chat, settings, ui |
| Gateway | 2 | gateway.gd, gateway.tscn |
| Managers | 6 | animation, char_setup, map, input, ui_panel, multiplayer |
| Utilities | 2 | credentials_utils, gateway_api |
| **TOTAL** | **32** | |

---

## Expected Results

### Before Reorganization

```
======================================================================
CHARACTERIZATION TEST: FILE ORGANIZATION BASELINE
======================================================================

--- PHASE 1: Core Files Existence ---
[PASS] client_launcher.gd exists
[PASS] client_main.gd exists
[PASS] login_screen files exist
[PASS] gateway files exist
[PASS] manager files exist

--- PHASE 2: Resource Path Validation ---
[PASS] critical paths accessible via ResourceLoader
[PASS] all scene files accessible

--- PHASE 3: Script Loading (Preload Safety) ---
[PASS] client_launcher.gd loads
[PASS] gateway.gd loads
[PASS] manager scripts load

--- PHASE 4: Scene Instantiation ---
[PASS] login_screen.tscn instantiation
[PASS] gateway.tscn instantiation
[PASS] character_select_screen.tscn instantiation

--- PHASE 5: Dependencies ---
[PASS] gateway.gd dependencies

======================================================================
TEST SUMMARY
======================================================================
Total Tests: 14
Passed: 14
Failed: 0
Success Rate: 100.0%
======================================================================
STATUS: ALL TESTS PASSED
======================================================================
```

### After Reorganization

Re-run test suite to verify:
- Same 14/14 PASS
- Same 100% success rate
- No broken imports
- No missing files

---

## How Characterization Tests Work

### The Golden Master Pattern

1. **Capture Current State**
   - Run test suite before changes
   - Document baseline behavior
   - 14 tests should all pass

2. **Make Changes**
   - Reorganize files
   - Move directories
   - Update imports

3. **Verify No Breakage**
   - Re-run test suite
   - Compare to baseline
   - Same tests should still pass

4. **Catch Regressions**
   - Any NEW failures indicate breakage
   - Failed tests tell you what broke
   - Easy to identify and fix

### Benefits

- **Safety Net**: Catch breaking changes immediately
- **Regression Prevention**: No silent failures
- **Quick Validation**: <5 second test execution
- **Clear Feedback**: Each test failure pinpoints exact issue
- **Documentation**: Test names describe what's being validated

---

## Using the Test Results

### Test Passes: All 14 tests PASS

✓ Safe to proceed with next steps
✓ No breaking changes detected
✓ File reorganization successful

### Test Fails: Some tests FAIL

1. Check which test(s) failed
2. Read error message carefully
   - Will show missing file path or broken import
3. Fix the issue
   - Move file if missing
   - Update preload statement if broken
4. Re-run test
5. Repeat until all tests pass

### Example Failure Messages

```
[FAIL] client_launcher.gd loads - Load error: Exception during load
  → Likely: Broken preload statement in launcher script
  → Fix: Find preload line, correct path

[FAIL] critical paths accessible via ResourceLoader -
    Inaccessible paths: ["res://source/client/ui/new_location/login_screen.gd"]
  → Likely: File moved but import not updated
  → Fix: Update preload to new location
```

---

## Pre-Reorganization Workflow

### 1. Baseline Execution
```
Open: res://tests/integration/test_file_organization_runner.tscn
Run:  F5
Expected: 14/14 PASS
Document: Copy results to TEST_RESULTS.md
```

### 2. Perform Reorganization
- Move files to new directories
- Update import paths
- Fix broken references

### 3. Post-Reorganization Validation
```
Open: res://tests/integration/test_file_organization_runner.tscn
Run:  F5
Expected: 14/14 PASS (same as baseline)
Compare: Verify no new failures
Document: Update TEST_RESULTS.md
```

### 4. Manual Validation
- Load login screen manually
- Verify gateway UI appears
- Test character select
- Connect to server (if available)

---

## Success Criteria

**Minimum Required**:
- 14/14 tests pass before reorganization
- 14/14 tests pass after reorganization
- Zero new failures introduced

**Ideal**:
- Baseline and post-reorganization results identical
- Execution completes in <5 seconds
- No manual fixes needed after reorganization

---

## Troubleshooting

### Test Won't Run
- Verify Godot version: Should be 4.5.1+
- Check file path: `tests/integration/test_file_organization_runner.tscn`
- Verify project structure: `source/client` directory intact

### All Tests Fail
- Likely: Project path issue
- Check: Are you in correct project directory?
- Verify: Godot can load any scene in `source/client/`

### Some Tests Fail After Reorganization
- This is expected if files were moved
- Identify which test failed
- Find missing file or update broken import
- Re-run test

### False Failures
- Ensure Godot editor properly indexed files (wait a few seconds)
- Try reimporting project (Tools > Reimport)
- Check console for detailed error messages

---

## Adding New Tests

To add tests for new files:

```gdscript
func test_new_feature_exists():
    """Verify new_feature files exist"""
    var test_name = "new_feature files exist"
    var script_path = "res://source/client/new_feature/new_feature.gd"

    if ResourceLoader.exists(script_path, "Script"):
        record_pass(test_name, script_path)
    else:
        record_fail(test_name, "File not found: " + script_path)
```

Then add call to `run_all_tests()` in appropriate phase.

---

## Related Tests

**Battle System Tests**: `tests/battle/test_turn_order.gd`
- Separate test suite for combat system
- Can run alongside file organization tests
- 8 tests validating DEX tie handling

**Future Integration Tests**:
- Network protocol validation
- Gameplay system integration
- UI response time validation

---

## Documentation References

| Document | Purpose |
|----------|---------|
| `FILE_ORGANIZATION_TEST_GUIDE.md` | Detailed test execution & maintenance |
| `TEST_COVERAGE_BASELINE.md` | Coverage inventory & risk analysis |
| `MMO_OPERATIONS_LOG.md` | All system changes & operations |
| `TEST_RESULTS.md` | Test execution results & outcomes |

---

## Key Points

1. **Golden Master Pattern** - Captures baseline, detects changes
2. **14 Tests** - Covers 32 critical files across 5 phases
3. **<5 Seconds** - Fast execution for rapid feedback
4. **Clear Failures** - Each test failure pinpoints exact issue
5. **Regression Prevention** - Catches breaking changes immediately

---

## Questions?

- **How to run?** → F5 in Godot editor (see Quick Start)
- **What does it test?** → See Test Structure section
- **What if tests fail?** → See Troubleshooting section
- **How to add tests?** → See Adding New Tests section
- **More details?** → See FILE_ORGANIZATION_TEST_GUIDE.md

---

**Status:** READY FOR EXECUTION
**Created:** 2025-11-14
**Next Step:** Run baseline test before file reorganization
