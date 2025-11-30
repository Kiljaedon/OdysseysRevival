extends CharacterBody2D

@export var speed: float = 300.0
@onready var sprite = $Sprite2D

var is_moving = false
var tween: Tween

func _ready():
	# Add collision shape
	if not $CollisionShape2D.shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(32, 32)
		$CollisionShape2D.shape = rect_shape

	# Start idle animation
	start_idle_animation()

func _physics_process(delta):
	handle_movement()
	move_and_slide()

func handle_movement():
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

	# Normalize diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed

		if not is_moving:
			is_moving = true
			start_walking_animation()

		# Sprite flipping for left/right movement
		if input_vector.x < 0:
			sprite.flip_h = true
		elif input_vector.x > 0:
			sprite.flip_h = false
	else:
		velocity = Vector2.ZERO
		if is_moving:
			is_moving = false
			start_idle_animation()

func start_idle_animation():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.9, 1.0)
	tween.tween_property(sprite, "modulate:a", 1.0, 1.0)

func start_walking_animation():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2(2.1, 1.9), 0.2)
	tween.tween_property(sprite, "scale", Vector2(1.9, 2.1), 0.2)