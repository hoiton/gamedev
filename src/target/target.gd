extends CharacterBody2D

@export var patrol_speed := 60.0
@export var chase_speed := 120.0
@export var lure_speed := 80.0
@export var lure_check_interval := 0.25
@export var lure_accept_distance := 12.0 # distance to "inspect" lure

var _alive := true
var _state : String = "idle"
var _player: Node2D = null

# Lure handling
var _lure_check_timer := 0.0
var _current_lure: Node = null
var _previous_state: String = "idle"
var _inspect_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	# existing vision connections if present ...

func _physics_process(delta: float) -> void:
	if not _alive: return

	# periodic lure scanning
	_lure_check_timer -= delta
	if _lure_check_timer <= 0.0:
		_lure_check_timer = lure_check_interval
		_scan_for_lures()

	match _state:
		"idle":
			velocity = Vector2.ZERO
		"patrol":
			# your patrol logic here
			pass
		"chase":
			if is_instance_valid(_player):
				var dir := (_player.global_position - global_position).normalized()
				velocity = dir * chase_speed
			else:
				_state = "idle"
		"lured":
			_process_lured_state(delta)
		"search":
			velocity = Vector2.ZERO

	move_and_slide()

func _scan_for_lures() -> void:
	# If already lured by something valid, keep it
	if is_instance_valid(_current_lure):
		return

	# find nearest lure in group "lure" or by checking nodes in tree
	var best_lure : Lure = null
	var best_score := -INF
	for lure in get_tree().get_nodes_in_group("lure"):
		if not is_instance_valid(lure):
			continue
		var dist = global_position.distance_to(lure.global_position)
		if dist <= lure.get_attract_radius():
			# scoring: prefer higher priority and closer
			var score = float(lure.get_priority()) - dist * 0.01
			if score > best_score:
				best_score = score
				best_lure = lure

	# if we found a lure, attract
	if best_lure:
		_current_lure = best_lure
		_previous_state = _state
		_state = "lured"
		_inspect_timer = 0.0
		# optional: play interest animation/sound

func _process_lured_state(delta: float) -> void:
	if not is_instance_valid(_current_lure):
		# lure gone — return to previous behavior
		_current_lure = null
		_state = _previous_state
		return

	var target_pos = _current_lure.get_position()
	var dir = (target_pos - global_position)
	var dist = dir.length()
	if dist > 0.0:
		velocity = dir.normalized() * lure_speed
	else:
		velocity = Vector2.ZERO

	# arrived?
	if dist <= lure_accept_distance:
		# "inspect" the lure for some seconds, then consume it (or ignore)
		_inspect_timer += delta
		velocity = Vector2.ZERO
		if _inspect_timer >= _current_lure.inspect_time:
			# consume / remove lure (optional chance)
			if is_instance_valid(_current_lure):
				_current_lure.queue_free()
			_current_lure = null
			_state = _previous_state
			# optional: reward or animation

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
