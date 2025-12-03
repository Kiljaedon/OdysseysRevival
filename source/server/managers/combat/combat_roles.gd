class_name CombatRoles
extends RefCounted

## Combat Role Definitions for Real-Time Combat
## Defines attack ranges, move speeds, and flanking bonuses per role

## ========== ROLE DEFINITIONS ==========

const ROLE_DATA = {
	"melee": {
		"name": "Melee",
		"attack_range": 120.0,
		"move_speed_mult": 1.0,  # 100% base speed
		"flank_front": 1.0,
		"flank_side": 1.15,  # +15%
		"flank_back": 1.30,  # +30%
		"uses_projectile": false,
		"projectile_texture": "",
		"identity": "Frontline tank, balanced flanking"
	},
	"hybrid": {
		"name": "Hybrid",
		"attack_range": 180.0,
		"move_speed_mult": 1.05,  # 5% faster
		"flank_front": 1.0,
		"flank_side": 1.25,  # +25%
		"flank_back": 1.50,  # +50% (rewards skilled positioning)
		"uses_projectile": false,
		"projectile_texture": "",
		"identity": "Duelist, enhanced flanking rewards"
	},
	"ranged": {
		"name": "Ranged",
		"attack_range": 350.0,
		"move_speed_mult": 1.15,  # 15% faster (kiting)
		"flank_front": 1.0,
		"flank_side": 0.90,  # -10% (penalized when surrounded)
		"flank_back": 0.80,  # -20% (must maintain distance)
		"uses_projectile": true,
		"projectile_texture": "res://assets/projectiles/Light Bolt.png",
		"identity": "Archer, must maintain range"
	},
	"caster": {
		"name": "Caster",
		"attack_range": 280.0,
		"move_speed_mult": 0.90,  # 10% slower
		"flank_front": 1.25,  # +25% always (glass cannon)
		"flank_side": 1.25,  # +25%
		"flank_back": 1.25,  # +25%
		"uses_projectile": true,
		"projectile_texture": "res://assets/projectiles/Arcane Bolt.png",
		"identity": "Mage, high damage, doesn't care about positioning"
	}
}

## ========== GETTERS ==========

static func get_role_data(role: String) -> Dictionary:
	"""Get all data for a combat role"""
	return ROLE_DATA.get(role, ROLE_DATA["melee"])

static func get_attack_range(role: String) -> float:
	"""Get attack range for role"""
	return get_role_data(role).attack_range

static func get_move_speed_mult(role: String) -> float:
	"""Get movement speed multiplier for role"""
	return get_role_data(role).move_speed_mult

static func get_flank_multiplier(role: String, flank_type: String) -> float:
	"""Get flanking damage multiplier for role and position"""
	var role_data = get_role_data(role)
	match flank_type:
		"front": return role_data.flank_front
		"side": return role_data.flank_side
		"back": return role_data.flank_back
	return 1.0

static func uses_projectile(role: String) -> bool:
	"""Check if role uses projectiles"""
	return get_role_data(role).uses_projectile

static func get_projectile_texture(role: String) -> String:
	"""Get projectile texture path for role"""
	return get_role_data(role).projectile_texture

## ========== VALIDATION ==========

static func is_valid_role(role: String) -> bool:
	"""Check if role exists"""
	return role in ROLE_DATA

static func get_all_roles() -> Array:
	"""Get list of all valid roles"""
	return ROLE_DATA.keys()
