# File Organization Test - Execution Checklist

**Test Suite**: Characterization Test (Golden Master Pattern)
**Created**: 2025-11-14
**Purpose**: Validate file reorganization safety

---

## Pre-Execution (Do This FIRST)

### Before Running Baseline Test

- [ ] Godot 4.5.1 installed and working
- [ ] Project loads without errors
- [ ] Can open any scene in editor
- [ ] Output tab visible at bottom of editor

### Backup Checklist

- [ ] Backup created: `GoldenSunMMO-Dev/source/client` directory
- [ ] Backup location documented
- [ ] Backup verified (can be extracted)

### Documentation Checklist

- [ ] TEST_RESULTS.md is accessible
- [ ] MMO_OPERATIONS_LOG.md is accessible
- [ ] Ready to record results

---

## Running the Baseline Test

### Step 1: Navigate to Test Runner

```
Path: res://tests/integration/test_file_organization_runner.tscn
```

Action:
1. In Godot editor, open FileSystem panel (left side)
2. Navigate to: `res:` > `tests` > `integration`
3. Double-click: `test_file_organization_runner.tscn`
4. Scene should open in editor

Status:
- [ ] Test runner scene opened
- [ ] Scene tree shows: `FileOrganizationTestRunner` (Node)

### Step 2: Execute Test

Action:
1. Press **F5** (or click Play button)
2. Wait for test to complete
3. Monitor Output tab at bottom

Expected:
- Output shows test progress
- Messages like "[PASS]" and "[FAIL]" appear
- Test completes in <5 seconds
- Final summary shows test count

Status:
- [ ] Test starts without errors
- [ ] Output messages appear
- [ ] Test completes successfully

### Step 3: Review Results

Action:
1. Look at Output tab final summary
2. Count: "Total Tests:", "Passed:", "Failed:"
3. Note exact numbers

Expected Results:
```
Total Tests: 14
Passed: 14
Failed: 0
Success Rate: 100.0%
STATUS: ALL TESTS PASSED
```

Status:
- [ ] All 14 tests passed (100%)
- [ ] No failures detected
- [ ] Success rate is 100.0%

### Step 4: Document Baseline

Action:
1. Copy all console output from Output tab
2. Open: `C:\Users\dougd\GoldenSunMMO\Documents\TEST_RESULTS.md`
3. Find section: "Baseline Results (Before Reorganization)"
4. Paste output in code block marked `[To be filled after running test suite]`
5. Update status from "PENDING" to completed date/time

Status:
- [ ] Console output copied
- [ ] TEST_RESULTS.md updated
- [ ] Baseline documented with timestamp
- [ ] All 14 tests recorded as PASS

---

## If Baseline Test FAILS

### Troubleshooting

If any tests fail in baseline (unexpected):

1. **Check Godot Version**
   - Help > About
   - Should be 4.5.1 or later
   - If older, update Godot first

2. **Check Project Structure**
   - Does `source/client/` directory exist?
   - Does `source/client/client_launcher.gd` exist?
   - If missing, restore from backup

3. **Check Scene Can Load**
   - Try opening any scene manually
   - Example: `source/client/ui/login_screen.tscn`
   - If it fails, there's a project issue

4. **Reimport Project**
   - Tools > Reimport
   - Wait for reimport to complete
   - Try test again

5. **Review Error Message**
   - Check Output for specific error
   - Look for test name that failed
   - Error message should indicate issue

### Document Failure

If baseline test fails:

Status:
- [ ] Identified reason for failure
- [ ] Documented in TEST_RESULTS.md
- [ ] This is a "known baseline failure"
- [ ] Noted why it fails (external cause)

---

## Before File Reorganization

### Final Checklist

- [ ] Baseline test executed
- [ ] Results documented in TEST_RESULTS.md
- [ ] All 14 tests passed (or failures documented)
- [ ] Backup created and verified
- [ ] Operations team briefed
- [ ] Ready to proceed with reorganization

### Communication

- [ ] Inform team: "Baseline test complete - ready for reorganization"
- [ ] Share baseline results
- [ ] Document in MMO_OPERATIONS_LOG.md

Status:
- [ ] Baseline complete
- [ ] Ready to proceed
- [ ] All documentation updated

---

## During File Reorganization

### Operations Checklist

- [ ] Track all file moves in MMO_OPERATIONS_LOG.md
- [ ] Document broken imports found
- [ ] Keep list of files updated/fixed
- [ ] Update preload statements as needed
- [ ] Save progress frequently

---

## Post-Reorganization Validation

### Step 1: Execute Post-Reorganization Test

```
Path: res://tests/integration/test_file_organization_runner.tscn
```

Action:
1. Open test runner scene (same as baseline)
2. Press F5 to run
3. Check Output for results

Expected:
- [ ] Same 14 tests run
- [ ] Same 14/14 PASS result (100%)
- [ ] No new failures

### Step 2: Compare to Baseline

Action:
1. Compare post-reorganization results to baseline
2. Check: Same "Total Tests: 14"?
3. Check: Same "Passed: 14"?
4. Check: Same "Success Rate: 100.0%"?

Result:
- [ ] Results match baseline (14/14 PASS)
- [ ] No new failures introduced
- [ ] Reorganization didn't break anything

### Step 3: Document Results

Action:
1. Copy post-reorganization test output
2. Update TEST_RESULTS.md
3. Add actual results and date
4. Compare section: "Same as baseline?"

Status:
- [ ] Post-reorganization results documented
- [ ] Comparison to baseline completed
- [ ] Differences (if any) noted

### Step 4: Manual Validation

If tests pass, do manual validation:

Test: Login Screen
- [ ] Can load: `source/client/ui/login_screen.tscn` in editor
- [ ] Scene renders without errors
- [ ] UI elements visible

Test: Gateway
- [ ] Can load: `source/client/gateway/gateway.tscn` in editor
- [ ] Scene renders without errors
- [ ] Buttons visible and functional

Test: Character Select
- [ ] Can load: `source/client/ui/character_select_screen.tscn`
- [ ] Scene renders without errors
- [ ] UI renders properly

Status:
- [ ] Login screen loads and works
- [ ] Gateway UI loads and works
- [ ] Character select loads and works
- [ ] No visual/functional issues

---

## Final Sign-Off

### Success Criteria Check

- [ ] Baseline test executed: 14/14 PASS
- [ ] Files reorganized per plan
- [ ] Post-reorganization test: 14/14 PASS
- [ ] Manual validation passed
- [ ] No broken imports remaining
- [ ] No broken scenes
- [ ] Execution time <5 seconds maintained

### Documentation Final

- [ ] TEST_RESULTS.md complete with results
- [ ] MMO_OPERATIONS_LOG.md updated
- [ ] All failures documented (if any)
- [ ] All fixes documented
- [ ] Reorganization marked COMPLETE

### Sign-Off

- [ ] Developer: Reviewed all tests and results
- [ ] QA: Verified 14/14 tests pass
- [ ] Operations: Confirmed files reorganized correctly
- [ ] Ready for deployment

Status:
- [ ] File reorganization COMPLETE
- [ ] All tests PASSING
- [ ] Ready for next phase

---

## Failure Response Protocol

### If Post-Reorganization Tests FAIL

1. **Identify Failed Test**
   - Which test failed? (check test name)
   - What's the error message?
   - Write it down

2. **Diagnose Root Cause**
   - Test name tells you what broke
   - Example: "client_launcher.gd loads" → preload error
   - Check that specific file

3. **Fix the Issue**
   - Update broken preload path
   - Move missing file to correct location
   - Verify file actually exists at new path

4. **Re-run Test**
   - Execute test_file_organization_runner.tscn again
   - F5 to run
   - Check if failure is fixed

5. **Repeat Until All Tests Pass**
   - Document each fix
   - Update MMO_OPERATIONS_LOG.md
   - Continue until 14/14 PASS

6. **Never Skip Failing Tests**
   - All 14 must pass
   - Can't proceed without 100% success
   - Failing tests prevent deployment

---

## Quick Reference

### Test Execution
```
1. Open: res://tests/integration/test_file_organization_runner.tscn
2. Press: F5
3. Wait: <5 seconds for completion
4. Check: Output tab for results
5. Expected: 14/14 PASS
```

### File Locations
- **Test File**: `tests/integration/test_file_organization.gd`
- **Test Runner**: `tests/integration/test_file_organization_runner.tscn`
- **Results**: `C:\Users\dougd\GoldenSunMMO\Documents\TEST_RESULTS.md`
- **Operations**: `C:\Users\dougd\GoldenSunMMO\Documents\MMO_OPERATIONS_LOG.md`

### Success Indicators
- [ ] 14 tests executed
- [ ] 14 tests passed
- [ ] 0 tests failed
- [ ] 100.0% success rate
- [ ] "ALL TESTS PASSED" message

### Failure Indicators
- [ ] Any test shows [FAIL]
- [ ] "Failed: X" (any number > 0)
- [ ] "STATUS: TESTS FAILED"
- [ ] Success rate < 100%

---

## Support & Troubleshooting

### Issue: Scene Won't Open
- Check: Does file exist at path?
- Try: Manual reload (F5 in editor)
- Try: Reimport project (Tools > Reimport)

### Issue: Tests Don't Run
- Check: Project loads without errors
- Check: Output tab is visible
- Try: Close and reopen project

### Issue: Tests Fail Unexpectedly
- Check: Error message in Output
- Check: Which specific test failed?
- See: FILE_ORGANIZATION_TEST_GUIDE.md for details

### Issue: Results Don't Match Expected
- Verify: Baseline was captured correctly
- Verify: File reorganization is complete
- Verify: All imports updated
- Check: Any manual file edits after reorganization?

---

## Contact

**Test Owner**: Test Engineer Agent (Phase 2 - Safety Net)
**Test Type**: Characterization Test (Golden Master Pattern)
**Date Created**: 2025-11-14

For detailed information:
- See: `tests/integration/CHARACTERIZATION_TEST_README.md`
- See: `tests/integration/FILE_ORGANIZATION_TEST_GUIDE.md`
- See: `tests/integration/TEST_COVERAGE_BASELINE.md`

---

**Status: READY FOR EXECUTION**

Proceed with baseline test when ready to begin file reorganization.
