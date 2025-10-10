extends CharacterBody2D

@export var max_speed: float = 220.0
@export var accel: float = 2000.0
@export var friction: float = 2600.0
@export var diagonal_normalize: bool = true

# Dash
@export var dash_speed: float = 420.0
@export var dash_time: float = 0.12
@export var dash_cooldown: float = 0.30

var _dash_left := 0.0
var _dash_cd_left := 0.0
var _dash_dir := Vector2.ZERO

func _physics_process(delta: float) -> void:
	# cooldowns
	_dash_cd_left = max(_dash_cd_left - delta, 0.0)

	# input vector
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	)
	if diagonal_normalize:
		input_vec = input_vec.normalized()

	# dash start
	if Input.is_action_just_pressed("dash") and _dash_cd_left == 0.0 and _dash_left <= 0.0:
		_dash_dir = (velocity.normalized() if velocity.length() > 1.0
					else (input_vec.normalized() if input_vec != Vector2.ZERO else Vector2.RIGHT))
		_dash_left = dash_time
		_dash_cd_left = dash_cooldown + dash_time

	# dash motion overrides regular accel
	if _dash_left > 0.0:
		velocity = _dash_dir * dash_speed
		_dash_left -= delta
	else:
		# accelerate toward target
		var target_vel := input_vec * max_speed
		var to_target := target_vel - velocity
		var a := (accel if input_vec != Vector2.ZERO else friction) * delta

		# move_toward for both axes
		velocity.x = move_toward(velocity.x, target_vel.x, a)
		velocity.y = move_toward(velocity.y, target_vel.y, a)

	move_and_slide()

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
