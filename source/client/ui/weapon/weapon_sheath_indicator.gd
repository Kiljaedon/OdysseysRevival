class_name WeaponSheathIndicator
extends HBoxContainer
## Weapon Sheath Visual Indicator
## Displays weapon state (sheathed/unsheathed) with icon only
## Position: Floating beside player character name

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var weapon_icon: TextureRect = $WeaponIcon

# ============================================================================
# ASSET PATHS
# ============================================================================

const ICON_SHEATHED = "res://assets/ui/kenney/rpg-expansion/cursorSword_bronze.png"
const ICON_UNSHEATHED = "res://assets/ui/kenney/rpg-expansion/cursorSword_gold.png"

# ============================================================================
# PROPERTIES
# ============================================================================

var weapon_state: WeaponState = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[WeaponSheathIndicator] _ready() called")
	
	# Weapon starts sheathed, so icon should be HIDDEN initially
	if weapon_icon:
		weapon_icon.visible = false
		print("[WeaponSheathIndicator] Icon initialized as HIDDEN (weapon starts sheathed)")
	else:
		push_warning("[WeaponSheathIndicator] WeaponIcon node not found!")

	# Center the container
	set_anchors_preset(Control.PRESET_CENTER_TOP)

	# Position icon to LEFT of player name on same line
	position = Vector2(-45, -75)
	print("[WeaponSheathIndicator] Positioned at (", position.x, ", ", position.y, ")")


func setup(weapon_state_node: WeaponState) -> void:
	"""Initialize the indicator with weapon state"""
	print("[WeaponSheathIndicator] setup() called")

	weapon_state = weapon_state_node

	# Connect to weapon state signals
	if weapon_state:
		weapon_state.state_changed.connect(_on_weapon_state_changed)
		print("[WeaponSheathIndicator] Connected to WeaponState.state_changed signal")
		
		# Set initial state
		_update_icon(weapon_state.is_sheathed)
		print("[WeaponSheathIndicator] Initial weapon state: ", "SHEATHED" if weapon_state.is_sheathed else "UNSHEATHED")
	else:
		push_warning("[WeaponSheathIndicator] WeaponState node is null!")


# ============================================================================
# VISUAL UPDATES
# ============================================================================

func _on_weapon_state_changed(is_sheathed: bool) -> void:
	"""Handle weapon state changes"""
	print("[WeaponSheathIndicator] _on_weapon_state_changed called - is_sheathed: ", is_sheathed)
	_update_icon(is_sheathed)


func _update_icon(is_sheathed: bool) -> void:
	"""Update icon texture and visibility based on weapon state"""
	if not weapon_icon:
		push_warning("[WeaponSheathIndicator] _update_icon: weapon_icon is null!")
		return

	if is_sheathed:
		# Hide icon when weapon is sheathed (safe/inactive state)
		weapon_icon.visible = false
		print("[WeaponSheathIndicator] Icon HIDDEN (weapon sheathed)")
	else:
		# Show icon when weapon is unsheathed (combat ready state)
		weapon_icon.visible = true
		weapon_icon.texture = load(ICON_UNSHEATHED)
		weapon_icon.modulate = Color(1.0, 0.9, 0.3, 1.0)  # Bright gold for combat ready
		print("[WeaponSheathIndicator] Icon VISIBLE (weapon unsheathed) - Color: GOLD")


func update_icon_for_sheathed_state() -> void:
	"""Set initial sheathed icon (called from _ready)"""
	if weapon_icon:
		weapon_icon.texture = load(ICON_SHEATHED)
		weapon_icon.modulate = Color(0.6, 0.6, 0.6, 0.8)
