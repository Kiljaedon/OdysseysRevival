extends Area2D
class_name BattleProjectile

## Projectile that travels in a direction and deals damage on hit

var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var attacker_id: String = ""
var attacker_team: String = ""
var lifetime: float = 3.0
var speed: float = 400.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Connect collision
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float):
	# Move projectile
	position += velocity * delta

	# Rotate to face direction of travel
	if velocity.length() > 0:
		rotation = velocity.angle()

	# Countdown lifetime
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

func _on_body_entered(body: Node):
	"""Hit something solid"""
	queue_free()

func _on_area_entered(area: Area2D):
	"""Hit another area (unit hitbox, etc.)"""
	# Check if it's an enemy unit
	if area.get_parent() is Node2D:
		var unit = area.get_parent()
		if unit.has_method("get") and unit.get("team") != attacker_team:
			# Hit enemy - projectile disappears
			queue_free()
