extends CharacterBody2D

@export var patrol_speed: float = 60.0
var _alive := true

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if not _alive: 
		return
	# (Optional) dumb idle/patrol placeholder so it moves a bit:
	velocity = Vector2.ZERO
	move_and_slide()

func die() -> void:
	if not _alive:
		return
	_alive = false
	set_physics_process(false)
	if has_node("AnimatedSprite2D"):
		var anim := $AnimatedSprite2D
		if "die" in anim.sprite_frames.get_animation_names():
			anim.play("die")
			anim.animation_finished.connect(func():
				queue_free()
			)
			return
	queue_free()
