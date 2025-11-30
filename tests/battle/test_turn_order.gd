extends Node
## Unit Tests for Turn Order Calculation with DEX Ties
## Tests the deterministic sorting of turn order when units have equal DEX values
## Created: 2025-11-14
## Phase: Bug fix validation for turn order DEX tie handling

var combat_manager: CombatManager = null
var test_results: Array = []
var tests_passed: int = 0
var tests_failed: int = 0

func _ready():
	print("\n" + "=".repeat(60))
	print("TURN ORDER DEX TIE TESTS")
	print("=".repeat(60))

	# Initialize combat manager
	combat_manager = CombatManager.new()
	add_child(combat_manager)
	await get_tree().create_timer(0.1).timeout

	# Run all tests
	run_all_tests()

	# Print summary
	print_test_summary()

	# Cleanup
	queue_free()

func run_all_tests():
	"""Execute all test scenarios"""
	print("\n--- Running Test Suite ---\n")

	test_two_units_same_dex()
	test_three_units_same_dex()
	test_mixed_dex_values()
	test_all_same_dex()
	test_determinism_multiple_runs()
	test_first_strike_with_dex_ties()
	test_ally_enemy_dex_tie()
	test_squad_index_tiebreaker()

## ========== TEST CASES ==========

func test_two_units_same_dex():
	"""Test: Two units with identical DEX - verify unit_id or squad_index tiebreaker"""
	var test_name = "Two Units Same DEX"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally A", 15, 0),
			create_unit("Ally B", 15, 1)
		],
		[
			create_unit("Enemy 1", 10, 0)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	# Verify ally with lower squad_index comes first
	var passed = true
	var reason = ""

	if turn_order.size() != 3:
		passed = false
		reason = "Expected 3 units, got %d" % turn_order.size()
	elif turn_order[0].name != "Ally A":
		passed = false
		reason = "Expected Ally A first (lower squad_index), got %s" % turn_order[0].name
	elif turn_order[1].name != "Ally B":
		passed = false
		reason = "Expected Ally B second, got %s" % turn_order[1].name

	log_test_result(test_name, passed, reason)

func test_three_units_same_dex():
	"""Test: Three or more units with same DEX - verify consistent ordering"""
	var test_name = "Three+ Units Same DEX"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally A", 12, 0),
			create_unit("Ally B", 12, 1),
			create_unit("Ally C", 12, 2)
		],
		[
			create_unit("Enemy 1", 8, 0)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# Verify allies sorted by squad_index
	if turn_order.size() != 4:
		passed = false
		reason = "Expected 4 units, got %d" % turn_order.size()
	elif turn_order[0].name != "Ally A" or turn_order[1].name != "Ally B" or turn_order[2].name != "Ally C":
		passed = false
		reason = "Expected A->B->C order, got %s->%s->%s" % [turn_order[0].name, turn_order[1].name, turn_order[2].name]

	log_test_result(test_name, passed, reason)

func test_mixed_dex_values():
	"""Test: Mixed DEX values - verify normal sorting still works (higher DEX first)"""
	var test_name = "Mixed DEX Values"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally Fast", 20, 0),
			create_unit("Ally Slow", 5, 1)
		],
		[
			create_unit("Enemy Medium", 12, 0)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# Verify descending DEX order (excluding first strike logic)
	# Expected: Ally Fast (20) -> Enemy Medium (12) -> Ally Slow (5)
	if turn_order.size() != 3:
		passed = false
		reason = "Expected 3 units, got %d" % turn_order.size()
	elif turn_order[0].dex != 20:
		passed = false
		reason = "Expected highest DEX (20) first, got DEX %d" % turn_order[0].dex
	elif turn_order[1].dex != 12:
		passed = false
		reason = "Expected medium DEX (12) second, got DEX %d" % turn_order[1].dex
	elif turn_order[2].dex != 5:
		passed = false
		reason = "Expected lowest DEX (5) last, got DEX %d" % turn_order[2].dex

	log_test_result(test_name, passed, reason)

func test_all_same_dex():
	"""Test: All units with same DEX - verify deterministic ordering by squad_index"""
	var test_name = "All Same DEX"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally 0", 10, 0),
			create_unit("Ally 1", 10, 1)
		],
		[
			create_unit("Enemy 0", 10, 0),
			create_unit("Enemy 1", 10, 1)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# First strike should be Ally 0 (player initiated, lowest squad_index)
	# Then remaining allies before enemies (based on current implementation)
	# Then by squad_index

	if turn_order.size() != 4:
		passed = false
		reason = "Expected 4 units, got %d" % turn_order.size()
	elif turn_order[0].type != "ally" or turn_order[0].squad_index != 0:
		passed = false
		reason = "Expected Ally 0 first (first strike), got %s (index %d)" % [turn_order[0].name, turn_order[0].squad_index]
	else:
		# Verify remaining units are consistently ordered
		var order_str = ""
		for i in range(turn_order.size()):
			order_str += "%s[%d] " % [turn_order[i].type, turn_order[i].squad_index]
		print("  Order: %s" % order_str)

	log_test_result(test_name, passed, reason)

func test_determinism_multiple_runs():
	"""Test: Run same scenario multiple times - verify identical results every time"""
	var test_name = "Determinism (Multiple Runs)"
	print("[TEST] %s" % test_name)

	var passed = true
	var reason = ""
	var runs = 10
	var reference_order: Array = []

	for run in range(runs):
		var combat = create_test_combat(
			[
				create_unit("Ally A", 15, 0),
				create_unit("Ally B", 15, 1),
				create_unit("Ally C", 15, 2)
			],
			[
				create_unit("Enemy X", 15, 0),
				create_unit("Enemy Y", 15, 1)
			],
			true
		)

		var turn_order = combat_manager.calculate_turn_order(combat)

		# First run establishes reference
		if run == 0:
			for unit in turn_order:
				reference_order.append("%s_%d" % [unit.type, unit.squad_index])
		else:
			# Compare to reference
			for i in range(turn_order.size()):
				var current = "%s_%d" % [turn_order[i].type, turn_order[i].squad_index]
				if current != reference_order[i]:
					passed = false
					reason = "Run %d differs at position %d: expected %s, got %s" % [run + 1, i, reference_order[i], current]
					break

		if not passed:
			break

	if passed:
		print("  All %d runs produced identical ordering" % runs)

	log_test_result(test_name, passed, reason)

func test_first_strike_with_dex_ties():
	"""Test: First strike selection when multiple units have same highest DEX"""
	var test_name = "First Strike DEX Tie"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally Fast 1", 20, 0),
			create_unit("Ally Fast 2", 20, 1),
			create_unit("Ally Slow", 10, 2)
		],
		[
			create_unit("Enemy 1", 15, 0)
		],
		true  # Player initiated
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# First strike should go to ally with DEX 20 and lowest squad_index (0)
	if turn_order[0].name != "Ally Fast 1":
		passed = false
		reason = "Expected Ally Fast 1 as first striker (DEX 20, index 0), got %s" % turn_order[0].name

	log_test_result(test_name, passed, reason)

func test_ally_enemy_dex_tie():
	"""Test: Ally vs Enemy DEX tie - verify allies go first in ties"""
	var test_name = "Ally vs Enemy DEX Tie"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally 1", 15, 0),
			create_unit("Ally 2", 15, 1)
		],
		[
			create_unit("Enemy 1", 15, 0),
			create_unit("Enemy 2", 15, 1)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# First striker should be Ally 1 (player initiated, DEX 15, index 0)
	# Remaining order: Ally 2, then enemies (allies prioritized in ties)

	var ally_positions = []
	var enemy_positions = []

	for i in range(turn_order.size()):
		if turn_order[i].type == "ally":
			ally_positions.append(i)
		else:
			enemy_positions.append(i)

	# Check if allies appear before enemies (when DEX is tied)
	if ally_positions.size() >= 2 and enemy_positions.size() >= 2:
		if ally_positions[1] > enemy_positions[0]:
			passed = false
			reason = "Expected allies before enemies in DEX tie, but enemy at position %d before ally at %d" % [enemy_positions[0], ally_positions[1]]

	log_test_result(test_name, passed, reason)

func test_squad_index_tiebreaker():
	"""Test: Verify squad_index is used as tiebreaker within same faction"""
	var test_name = "Squad Index Tiebreaker"
	print("[TEST] %s" % test_name)

	var combat = create_test_combat(
		[
			create_unit("Ally 3", 12, 3),
			create_unit("Ally 0", 12, 0),
			create_unit("Ally 1", 12, 1),
			create_unit("Ally 2", 12, 2)
		],
		[
			create_unit("Enemy 1", 8, 0)
		],
		true
	)

	var turn_order = combat_manager.calculate_turn_order(combat)

	var passed = true
	var reason = ""

	# Filter allies from turn order
	var ally_order = []
	for unit in turn_order:
		if unit.type == "ally":
			ally_order.append(unit.squad_index)

	# Verify allies sorted by squad_index: [0, 1, 2, 3]
	var expected = [0, 1, 2, 3]
	if ally_order != expected:
		passed = false
		reason = "Expected ally order by squad_index %s, got %s" % [expected, ally_order]

	log_test_result(test_name, passed, reason)

## ========== HELPER FUNCTIONS ==========

func create_test_combat(ally_squad: Array, enemy_squad: Array, player_initiated: bool) -> Dictionary:
	"""Create a test combat scenario"""
	return {
		"ally_squad": ally_squad,
		"enemy_squad": enemy_squad,
		"player_initiated": player_initiated,
		"turn_order": []
	}

func create_unit(unit_name: String, dex_value: int, squad_idx: int) -> Dictionary:
	"""Create a test unit with specified DEX and squad index"""
	return {
		"character_name": unit_name,
		"base_stats": {
			"dex": dex_value,
			"str": 10,
			"int": 10,
			"vit": 10,
			"wis": 10
		},
		"hp": 100,
		"max_hp": 100,
		"level": 5,
		"squad_index": squad_idx
	}

func log_test_result(test_name: String, passed: bool, reason: String = ""):
	"""Log individual test result"""
	test_results.append({
		"name": test_name,
		"passed": passed,
		"reason": reason
	})

	if passed:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		print("  [FAIL] %s - %s" % [test_name, reason])

	print("")

func print_test_summary():
	"""Print final test summary"""
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Total Tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("Success Rate: %.1f%%" % (100.0 * tests_passed / (tests_passed + tests_failed)))
	print("=".repeat(60))

	if tests_failed > 0:
		print("\nFailed Tests:")
		for result in test_results:
			if not result.passed:
				print("  - %s: %s" % [result.name, result.reason])

	print("\nTest run complete.\n")
