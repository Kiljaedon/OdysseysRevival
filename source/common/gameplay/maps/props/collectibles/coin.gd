extends Area2D


@export_enum("blue", "gold") var coin_type: String = "blue"

@onready var coin_anim: AnimatedSprite2D = $AnimatedSprite2D

var collected: bool = false


func _ready() -> void:
	coin_anim.play(coin_type + "_coin")
	# NETWORK DEPENDENCY DISABLED FOR CLIENT-FIRST DEVELOPMENT
	# Original: if multiplayer.is_server():
	# For client-first development, always connect for testing
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is GamePlayer or collected:
		return
	
	# To be sure it's called once.
	collected = true
	
	# NETWORK DEPENDENCY DISABLED FOR CLIENT-FIRST DEVELOPMENT
	# Original network synchronization code commented out
	# var container: ReplicatedPropsContainer = PropsAccess.get_owner_container(self)
	# if not container:
	#	return

	# Simple client-first behavior for testing
	rp_collect(true)  # Just play collection animation and remove


# Client-side ops (pure visuals)


func rp_collect(delete: bool) -> void:
	coin_anim.play(&"collected")
	coin_anim.animation_finished.connect(
		queue_free if delete else rp_pause,
		CONNECT_ONE_SHOT
	)


func rp_pause() -> void:
	hide()
	$CollisionShape2D.set_deferred(&"disabled", true)
	set_deferred(&"monitoring", false)


func rp_unpause() -> void:
	coin_anim.play(coin_type + "_coin")
	$CollisionShape2D.set_deferred(&"disabled", false)
	set_deferred(&"monitoring", true)
	show()
	collected = false
