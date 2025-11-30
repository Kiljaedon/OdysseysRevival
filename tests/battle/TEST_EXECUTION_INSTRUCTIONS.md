# Turn Order Test Execution Instructions

## Test File Location
`C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\tests\battle\test_turn_order.gd`

## Test Runner Scene
`C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\tests\battle\test_turn_order_runner.tscn`

## Manual Execution (Godot Editor)

### Method 1: Run Test Scene
1. Open Godot Editor
2. Open project: `C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev\project.godot`
3. Navigate to `res://tests/battle/test_turn_order_runner.tscn`
4. Press F6 (or Play Scene button) to run the test scene
5. Check Output console for test results

### Method 2: Attach to Main Scene
1. Open Godot Editor
2. Open main scene: `res://source/common/main.tscn`
3. Add `test_turn_order.gd` as a child node script
4. Run main scene (F5)
5. Check Output console for test results

### Method 3: CLI Execution (if Godot CLI available)
```bash
# Navigate to project directory
cd C:\Users\dougd\GoldenSunMMO\GoldenSunMMO-Dev

# Run headless test (requires Godot in PATH)
godot --headless --path . --script tests/battle/test_turn_order.gd
```

## Expected Test Output

```
============================================================
TURN ORDER DEX TIE TESTS
============================================================

--- Running Test Suite ---

[TEST] Two Units Same DEX
  [PASS] Two Units Same DEX

[TEST] Three+ Units Same DEX
  [PASS] Three+ Units Same DEX

[TEST] Mixed DEX Values
  [PASS] Mixed DEX Values

[TEST] All Same DEX
  Order: ally[0] ally[1] enemy[0] enemy[1]
  [PASS] All Same DEX

[TEST] Determinism (Multiple Runs)
  All 10 runs produced identical ordering
  [PASS] Determinism (Multiple Runs)

[TEST] First Strike DEX Tie
  [PASS] First Strike DEX Tie

[TEST] Ally vs Enemy DEX Tie
  [PASS] Ally vs Enemy DEX Tie

[TEST] Squad Index Tiebreaker
  [PASS] Squad Index Tiebreaker

============================================================
TEST SUMMARY
============================================================
Total Tests: 8
Passed: 8
Failed: 0
Success Rate: 100.0%
============================================================

Test run complete.
```

## Test Scenarios Verified

1. **Two Units Same DEX**: Verifies tiebreaker by squad_index
2. **Three+ Units Same DEX**: Ensures consistent ordering for multiple ties
3. **Mixed DEX Values**: Confirms normal DEX sorting still works
4. **All Same DEX**: Tests complete tie scenario with allies and enemies
5. **Determinism**: Runs 10 iterations to ensure consistent results
6. **First Strike DEX Tie**: Validates first striker selection when multiple units have same DEX
7. **Ally vs Enemy DEX Tie**: Confirms allies get priority over enemies in ties
8. **Squad Index Tiebreaker**: Verifies lower squad_index = higher priority

## Bug Fix Verification

The tests validate the fix implemented in:
- `source/server/managers/combat_manager.gd` (lines 129-132, 150-153, 165-174)

**Key Changes:**
- First strike selection now uses squad_index as tiebreaker when DEX is equal
- Remaining units sorted with proper tie-breaking: DEX > Ally priority > squad_index
- Deterministic ordering guaranteed for all scenarios

## Troubleshooting

### Test Fails to Load
- Verify CombatManager class exists at `res://source/server/managers/combat_manager.gd`
- Verify ServerBattleCalculator exists at `res://source/server/server_battle_calculator.gd`
- Check Godot console for script errors

### Test Scene Won't Run
- Verify test_turn_order_runner.tscn exists in `res://tests/battle/`
- Check that script path in .tscn file is correct: `res://tests/battle/test_turn_order.gd`

### No Output in Console
- Enable "Verbose" output in Godot: Project > Project Settings > Debug > GDScript
- Check that print() statements are not suppressed in project settings

## Next Steps After Testing

1. Record results in `C:\Users\dougd\GoldenSunMMO\Documents\TEST_RESULTS.md`
2. If all tests pass, bug fix is verified
3. If any tests fail, review combat_manager.gd implementation
4. Update MMO_OPERATIONS_LOG.md with final status
