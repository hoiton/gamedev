extends CharacterBody2D

@export var max_speed: float = 220.0
@export var accel: float = 2000.0
@export var friction: float = 2600.0
@export var diagonal_normalize: bool = true

@onready var _kill_area: Area2D = $MeleeArea
var _enemies_in_range: Array[Node] = []


func _physics_process(delta: float) -> void:
	# input vector
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	)
	if diagonal_normalize:
		input_vec = input_vec.normalized()

	var target_vel := input_vec * max_speed
	var a := (accel if input_vec != Vector2.ZERO else friction) * delta

	# move_toward for both axes
	velocity.x = move_toward(velocity.x, target_vel.x, a)
	velocity.y = move_toward(velocity.y, target_vel.y, a)

	move_and_slide()
	
	if Input.is_action_just_pressed("kill"):
		_try_knife_kill()


	# Optional: flip/rotate sprite to face movement
	if has_node("Sprite"):
		var s = get_node("Sprite")
		if s is AnimatedSprite2D:
			_update_anim(s, input_vec)

func _update_anim(anim: AnimatedSprite2D, dir: Vector2) -> void:
	# Expect animations named: idle, walk_up, walk_down, walk_side
	if dir == Vector2.ZERO and velocity.length() < 5.0:
		anim.play("idle")
		return

	# choose dominant axis for 4-dir; swap for 8-dir as you like
	if abs(dir.y) >= abs(dir.x):
		anim.play("walk_down" if dir.y >= 0.0 else "walk_up")
	else:
		anim.play("walk_side")
		anim.flip_h = dir.x < 0.0

func _ready() -> void:
	if is_instance_valid(_kill_area):
		_kill_area.body_entered.connect(_on_kill_body_entered)
		_kill_area.body_exited.connect(_on_kill_body_exited)

func _on_kill_body_entered(body: Node) -> void:
	if body.is_in_group("target"):
		_enemies_in_range.append(body)

func _on_kill_body_exited(body: Node) -> void:
	if body.is_in_group("target"):
		_enemies_in_range.erase(body)

func _try_knife_kill() -> void:
	if _enemies_in_range.is_empty():
		return
	var closest: Node = null
	var min_d := INF
	for e in _enemies_in_range:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			closest = e
	if closest and closest.has_method("die"):
		closest.die()
