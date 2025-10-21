extends CharacterBody2D

const LureScene := preload("res://environment/lure.tscn")
const CoinThrowScene := preload("res://environment/coin_throw.tscn")

@export var coin_max_range: float = 300.0
@export var coin_collision_mask: int = 1  # set to the same as your walls/level
@export var lure_throw_speed: float = 420.0
@export var lure_cooldown: float = 1.0
var _lure_cd_timer := 0.0
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
			
	if _lure_cd_timer > 0.0:
		_lure_cd_timer = max(0.0, _lure_cd_timer - delta)

	# throw lure input (use whichever input you chose)
	if Input.is_action_just_pressed("lure") and _lure_cd_timer <= 0.0:
		_throw_lure()
		_lure_cd_timer = lure_cooldown
		
	if Input.is_action_just_pressed("throw"):
		var mouse_pos := get_global_mouse_position()
		var land := _compute_coin_target(mouse_pos)
		_throw_coin(land)

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

func _throw_lure() -> void:
	var lure = LureScene.instantiate()
	# spawn in the current scene root or a specific "entities" node
	get_tree().current_scene.add_child(lure)
	# throw in the aim direction based on mouse or facing
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(1, 0)
	# spawn a little in front of the player
	lure.global_position = global_position + aim_dir * 12
	# optional: give it an initial motion (we don't have a RigidBody here; simulate a toss)
	# perform a short arc tween so it lands a bit further:
	var land_pos = global_position + aim_dir * 42
	lure.global_position = global_position + aim_dir * 12
	# simple immediate set (if you want an arc, add a Tween)
	lure.global_position = land_pos
	# optionally play throw sound / animation

func _compute_coin_target(click_pos: Vector2) -> Vector2:
	var origin := global_position
	var to := click_pos
	var dir := (to - origin)
	var dist := dir.length()
	if dist < 1.0:
		return origin
	dir = dir.normalized()

	# clamp to max range
	var wanted_end: Vector2 = origin + dir * min(dist, coin_max_range)

	# raycast to respect walls/obstacles
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, wanted_end)
	query.collision_mask = coin_collision_mask
	var hit := space.intersect_ray(query)

	if hit and hit.has("position"):
		# land just before the wall
		return hit.position - dir * 8.0
	else:
		return wanted_end

func _throw_coin(target_pos: Vector2) -> void:
	var coin := CoinThrowScene.instantiate()
	get_tree().current_scene.add_child(coin)  # add to root, not under Player
	coin.launch(global_position, target_pos)
