extends SceneTree

func _init():
	print("=== VERIFYING COMBAT MATH ===")
	
	var StatsCalculator = load("res://source/common/combat/stats_calculator.gd")
	var ElementalSystem = load("res://source/common/combat/elemental_system.gd")
	
	if not StatsCalculator:
		print("ERROR: Failed to load StatsCalculator")
		quit(1)
		return
		
	if not ElementalSystem:
		print("ERROR: Failed to load ElementalSystem")
		quit(1)
		return
		
	print("Modules loaded successfully.")
	
	# Test Case 1: Basic Physical Damage
	var attacker = {"str": 10}
	var defender = {"vit": 10}
	var dmg = StatsCalculator.calculate_physical_damage(attacker, defender, 0)
	# (10*1.5 + 0) - (10*0.5) = 15 - 5 = 10
	print("Test 1 (Phys 10 vs 10): Expected 10.0, Got ", dmg)
	if dmg != 10.0:
		print("FAIL: Damage calculation incorrect")
		quit(1)
		return

	# Test Case 2: Elemental Weakness
	var mod = ElementalSystem.get_elemental_modifier("Mars", "Venus")
	# Mars > Venus (Fire burns Earth?) - Check chart.
	# Mars -> Venus: 1.0 (Neutral in this chart? Let's check source)
	# "Mars": {"Venus": 1.0, "Mercury": 0.8, "Mars": 1.0, "Jupiter": 1.2}
	print("Test 2 (Mars vs Venus): Expected 1.0, Got ", mod)
	
	var mod2 = ElementalSystem.get_elemental_modifier("Mars", "Jupiter")
	print("Test 3 (Mars vs Jupiter): Expected 1.2, Got ", mod2)
	if mod2 != 1.2:
		print("FAIL: Elemental modifier incorrect")
		quit(1)
		return

	print("=== ALL TESTS PASSED ===")
	quit(0)
