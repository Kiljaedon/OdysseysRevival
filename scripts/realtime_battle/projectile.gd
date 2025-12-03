extends Area2D
class_name BattleProjectile

## Projectile that travels in a direction and deals damage on hit

var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var attacker_id: String = ""
var attacker_team: String = ""
var lifetime: float = 3.0
var speed: float = 600.0  # Match server PROJECTILE_SPEED
var server_authoritative: bool = false  # When true, only server controls despawn

## Animation
var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.03  # Seconds per frame (faster for smooth animation during travel)
var total_frames: int = 8

var sprite: Sprite2D = null  # Set in _ready or manually

func _ready():
	# Get sprite reference
	sprite = get_node_or_null("Sprite2D")
	if sprite:
		print("[PROJECTILE] Sprite found, hframes=%d, frame=%d, texture=%s" % [sprite.hframes, sprite.frame, sprite.texture])
		# Ensure animation starts at frame 0
		sprite.frame = 0
		anim_frame = 0
	else:
		print("[PROJECTILE] ERROR: No Sprite2D found!")

	# Connect collision
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float):
	# Move projectile
	position += velocity * delta

	# Rotate to face direction of travel
	if velocity.length() > 0:
		rotation = velocity.angle()

	# Animate sprite frames
	if sprite and sprite.hframes > 1:
		anim_timer += delta
		if anim_timer >= anim_speed:
			anim_timer = 0.0
			anim_frame = (anim_frame + 1) % sprite.hframes
			sprite.frame = anim_frame

	# Countdown lifetime (only for non-server-authoritative projectiles)
	if not server_authoritative:
		lifetime -= delta
		if lifetime <= 0:
			queue_free()

func initialize(from_pos: Vector2, direction: Vector2, dmg: int, attacker: String, team: String):
	"""Set up projectile"""
	position = from_pos
	velocity = direction.normalized() * speed
	damage = dmg
	attacker_id = attacker
	attacker_team = team

func set_server_velocity(vel: Vector2):
	"""Override velocity with server-authoritative value"""
	velocity = vel
	server_authoritative = true  # Server controls this projectile

func _on_body_entered(body: Node):
	"""Hit something solid"""
	if server_authoritative:
		return  # Server controls despawn
	queue_free()

func _on_area_entered(area: Area2D):
	"""Hit another area (unit hitbox, etc.)"""
	if server_authoritative:
		return  # Server controls despawn
	# Check if it's an enemy unit
	if area.get_parent() is Node2D:
		var unit = area.get_parent()
		if unit.has_method("get") and unit.get("team") != attacker_team:
			# Hit enemy - projectile disappears
			queue_free()
