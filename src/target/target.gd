extends CharacterBody2D

@export var patrol_speed := 60.0
@export var chase_speed := 120.0
@export var lure_speed := 80.0
@export var lure_check_interval := 0.25
@export var lure_accept_distance := 12.0 # distance to "inspect" lure

@onready var _agent: NavigationAgent2D = $NavigationAgent2D

var _alive := true
var _state : String = "idle"
var _player: Node2D = null

# Lure handling
var _lure_check_timer := 0.0
var _current_lure: Node = null
var _previous_state: String = "idle"
var _inspect_timer := 0.0


func _ready() -> void:
	# Tweak as needed
	add_to_group("enemy")
	
	_agent.path_desired_distance = 6.0
	_agent.target_desired_distance = 8.0
	_agent.avoidance_enabled = false # flip to true if you want local avoidance
	# Optional: handle dynamic obstacles better
	_agent.max_speed = max(chase_speed, lure_speed)

# Helper: speed based on state
func _current_speed() -> float:
	match _state:
		"chase": return chase_speed
		"lured": return lure_speed
		"patrol": return patrol_speed
		_: return 0.0

# Helper: compute path-steered velocity toward agent's next corner
func _steer_along_path(desired_speed: float) -> Vector2:
	if _agent.is_navigation_finished():
		return Vector2.ZERO
	var next_pos := _agent.get_next_path_position()
	var to_next := next_pos - global_position
	if to_next.length() < 0.001:
		return Vector2.ZERO
	return to_next.normalized() * desired_speed

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
			_agent.set_target_position(global_position) # clear path

		"patrol":
			# your patrol logic here; when you pick a patrol waypoint:
			# _agent.set_target_position(next_waypoint_global_pos)
			velocity = _steer_along_path(_current_speed())

		"chase":
			if is_instance_valid(_player):
				# Continuously retarget so the path updates as the player moves
				_agent.set_target_position(_player.global_position)
				velocity = _steer_along_path(_current_speed())
				if _agent.is_target_reached():
					# optional: close-range direct move or attack
					var dir := (_player.global_position - global_position).normalized()
					velocity = dir * chase_speed
			else:
				_state = "idle"

		"lured":
			# uses pathfinding; arrival handled in _process_lured_state
			if is_instance_valid(_current_lure):
				_agent.set_target_position(_current_lure.get_position())
				velocity = _steer_along_path(_current_speed())
			else:
				_state = _previous_state

		"search":
			velocity = Vector2.ZERO
			_agent.set_target_position(global_position)

	move_and_slide()

# --- unchanged scan, with lured behaviour now path-driven ---
func _scan_for_lures() -> void:
	if is_instance_valid(_current_lure):
		return
	var best_lure : Lure = null
	var best_score := -INF
	for lure in get_tree().get_nodes_in_group("lure"):
		if not is_instance_valid(lure):
			continue
		var dist = global_position.distance_to(lure.global_position)
		if dist <= lure.get_attract_radius():
			var score = float(lure.get_priority()) - dist * 0.01
			if score > best_score:
				best_score = score
				best_lure = lure
	if best_lure:
		_current_lure = best_lure
		_previous_state = _state
		_state = "lured"
		_inspect_timer = 0.0

func _process_lured_state(delta: float) -> void:
	if not is_instance_valid(_current_lure):
		_current_lure = null
		_state = _previous_state
		return

	# Arrival check uses nav target distance
	if _agent.is_target_reached() or global_position.distance_to(_current_lure.get_position()) <= lure_accept_distance:
		_inspect_timer += delta
		velocity = Vector2.ZERO
		if _inspect_timer >= _current_lure.inspect_time:
			if is_instance_valid(_current_lure):
				_current_lure.queue_free()
			_current_lure = null
			_state = _previous_state

func die() -> void:
	if not _alive:
		return
	_alive = false
	set_physics_process(false)
	if has_node("AnimatedSprite2D"):
		var anim := $AnimatedSprite2D
		if "die" in anim.sprite_frames.get_animation_names():
			anim.play("die")
			#anim.animation_finished.connect(func():
				#queue_free()
			#)
			return
	queue_free()
