extends Node
class_name TestPlayerController

@export var speed: float = 200.0
var gamepiece: Path2D
var path_follow: PathFollow2D

func _ready():
	# Find the gamepiece and path follow
	gamepiece = get_parent()
	if gamepiece is Path2D:
		path_follow = gamepiece.get_node("PathFollow2D")

func _physics_process(delta):
	if not path_follow:
		return

	var input_vector = Vector2.ZERO

	# Get input from WASD/Arrow keys
	if Input.is_action_pressed("up"):
		input_vector.y -= 1
	if Input.is_action_pressed("down"):
		input_vector.y += 1
	if Input.is_action_pressed("left"):
		input_vector.x -= 1
	if Input.is_action_pressed("right"):
		input_vector.x += 1

	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		var movement = input_vector * speed * delta

		# Move the path follow position
		var current_pos = path_follow.global_position
		var new_pos = current_pos + movement

		# Update the curve to the new position
		var curve = Curve2D.new()
		curve.add_point(Vector2.ZERO)
		curve.add_point(gamepiece.to_local(new_pos))
		gamepiece.curve = curve
		path_follow.progress_ratio = 1.0

		# Handle sprite flipping
		var sprite = path_follow.get_node_or_null("CharacterGFX/Sprite2D")
		if sprite:
			if input_vector.x < 0:
				sprite.flip_h = true
			elif input_vector.x > 0:
				sprite.flip_h = false