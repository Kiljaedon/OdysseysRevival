# File Organization Characterization Test

## Overview
This is a **Golden Master (Characterization) Test** that captures the baseline behavior of the client codebase BEFORE file reorganization. It serves as a safety net to detect any breaking changes during the reorganization process.

**Test File**: `C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\tests\integration\test_file_organization.gd`
**Test Runner**: `C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\tests\integration\test_file_organization_runner.tscn`

## Test Purpose
Verify that file reorganization does NOT break:
1. Client entry points (client_launcher.gd, client_main.gd)
2. UI screen loading (login_screen, character select)
3. Gateway initialization
4. Manager file accessibility
5. Preload/import statements
6. Scene instantiation

## Test Structure

### Phase 1: Core Files Existence
- Verifies all critical .gd and .tscn files exist at expected paths
- Tests: 5 tests
- Quick sanity check for reorganization completeness

### Phase 2: Resource Path Validation
- Uses `ResourceLoader.exists()` to verify paths are accessible
- Tests critical paths: entry points, UI screens, gateway, common utilities
- Tests: 2 tests
- Validates that Godot can find all resources

### Phase 3: Script Loading (Preload Safety)
- Attempts to load scripts to catch preload errors
- Focuses on: launcher, gateway, managers
- Tests: 3 tests
- Catches broken import chains immediately

### Phase 4: Scene Instantiation
- Loads and instantiates key scenes
- Tests: 3 tests
- Validates scenes are fully functional

### Phase 5: Key Manager References
- Verifies gateway.gd can reference required utilities
- Tests: 1 test
- Validates dependency chain

## Running the Tests

### In Godot Editor
1. Open `tests/integration/test_file_organization_runner.tscn`
2. Press Play (F5)
3. Check the Output console for test results

### Expected Output Format
```
======================================================================
CHARACTERIZATION TEST: FILE ORGANIZATION BASELINE
======================================================================
Purpose: Capture baseline state before file reorganization
Date: [timestamp]
======================================================================

--- PHASE 1: Core Files Existence ---

[PASS] client_launcher.gd exists - res://source/client/client_launcher.gd
[PASS] client_main.gd exists - res://source/client/client_main.gd
...

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

## Test Results Interpretation

### All Tests Pass (Expected Before Reorganization)
- Baseline is captured successfully
- Safe to proceed with file reorganization
- Tests can be re-run after reorganization to verify no breakage

### Some Tests Fail
- Check which tests failed
- Review the detailed error messages
- These become "known baseline failures" during reorganization
- Document why they fail (external dependencies, missing configs, etc.)

## Key Tests Explained

### test_critical_paths_with_resource_loader()
**Most Important**: Verifies that all critical file paths are accessible via Godot's ResourceLoader
- If this fails, reorganization has broken file paths
- Catches: moved files, broken imports, missing resources

### test_launcher_script_loads() / test_gateway_script_loads()
**Critical Entry Points**: Verifies entry point scripts load without preload errors
- If launcher fails, client won't boot
- If gateway fails, login screen won't show

### test_manager_scripts_load()
**Core Functionality**: Verifies all managers can be loaded
- Catches broken preload chains in managers
- Tests: animation, character setup, map, input, UI panel managers

### test_*_scene_instantiation()
**UI Validation**: Verifies scenes can be instantiated
- If login scene fails, players can't login
- If gateway fails, login screen breaks
- Tests actual scene functionality, not just file existence

## Before Reorganization Workflow

1. **Run baseline test**
   - Execute test_file_organization_runner.tscn
   - Verify all tests pass
   - Document success in TEST_RESULTS.md

2. **Perform reorganization**
   - Move files to new directories
   - Update imports/preloads as needed
   - Fix broken references

3. **Re-run tests**
   - Execute test_file_organization_runner.tscn again
   - Verify all previous passing tests still pass
   - Investigate any new failures

4. **Validate manually**
   - Load login screen
   - Verify gateway UI
   - Test character selection
   - Check multiplayer connection

## Adding New Tests

To add tests for new UI screens or managers:

```gdscript
func test_new_feature_file_exists():
    """Verify new_feature files exist"""
    var test_name = "new_feature files exist"
    var script_path = "res://source/client/new_feature/new_feature.gd"

    if ResourceLoader.exists(script_path, "Script"):
        record_pass(test_name, script_path)
    else:
        record_fail(test_name, "File not found: " + script_path)
```

Then add the test to `run_all_tests()` in the appropriate phase.

## Test Maintenance

- Update test paths when files are reorganized
- Add tests for new critical files
- Keep test count under 20 for fast execution
- Document known failures with reasons

## Known Baseline Failures

Currently: **NONE** (all tests should pass before reorganization)

After reorganization, document any expected failures here:
- `[broken_reference]` - Reason: external config issue
- etc.

## Success Criteria

- All file existence tests pass
- All script loading tests pass
- All scene instantiation tests pass
- 100% test success rate before reorganization
- After reorganization: Same 100% success rate

## Related Documentation

- `C:\Users\dougd\GoldenSunMMO\Documents\TEST_RESULTS.md` - Overall test results
- `C:\Users\dougd\GoldenSunMMO\Documents\MMO_OPERATIONS_LOG.md` - Reorganization log
- `tests/battle/test_turn_order.gd` - Example unit test

## Contact & Notes

This test was created as part of Phase 2 (Safety Net) of the file reorganization project.

If tests fail after reorganization:
1. Check error messages for exact failed path
2. Verify file was actually moved (not deleted)
3. Search for references in other files
4. Update preload/import statements
5. Re-run tests to verify fix
