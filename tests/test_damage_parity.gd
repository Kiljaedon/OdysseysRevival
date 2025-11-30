extends SceneTree

func _init():
	print("TEST: Verifying SharedBattleCalculator consistency...")
	
	var shared = load("res://source/common/combat/shared_battle_calculator.gd")
	if shared == null:
		print("FAIL: Could not load SharedBattleCalculator")
		quit(1)
		return
		
	var client_calc = load("res://scripts/battle/battle_damage_calculator.gd")
	var server_calc = load("res://source/server/server_battle_calculator.gd").new()
	
	# Test Case 1: Basic Physical Damage
	var atk = {"base_stats": {"str": 50, "int": 10}, "character_name": "Hero", "combat_role": "melee"}
	var def = {"base_stats": {"vit": 40, "int": 10}, "character_name": "Monster", "combat_role": "melee"}
	
	var dmg_shared = shared.calculate_physical_damage(
		{"attack": 100, "defense": 20}, # 50*2, 40/2
		{"defense": 20}
	)
	
	print("Shared Calc Result: ", dmg_shared)
	
	# Server Verification
	var dmg_server = server_calc.calculate_damage(atk, def)
	print("Server Calc Result: ", dmg_server)
	
	if dmg_shared == dmg_server:
		print("PASS: Server matches Shared logic")
	else:
		print("FAIL: Server %d != Shared %d" % [dmg_server, dmg_shared])
		quit(1)
		
	print("ALL TESTS PASSED")
	quit(0)
