extends CharacterBody2D

@export var patrol_speed := 40.0
@export var chase_speed := 120.0
@export var lure_speed := 80.0
@export var lure_check_interval := 0.25
@export var lure_accept_distance := 12.0 # distance to "inspect" lure

@export var patrol_path: Path2D
@export var patrol_loop := true
@export var patrol_point_spacing := 8.0 # pixels between sampled points
@export var patrol_wait := 0.0

var _patrol_points: PackedVector2Array = []
var _patrol_i := 0
var _patrol_wait_t := 0.0

@export var body_detect_radius := 180.0
@export var body_detect_interval := 0.25
@export var body_confirm_distance := 14.0 # how close to "confirm" the body

var _body_scan_timer := 0.0
var _known_bodies := {} # instance_id -> true (avoid re-reacting)
var _current_body: Node2D = null



@onready var _agent: NavigationAgent2D = $NavigationAgent2D

var _alive := true
var _state : String = "idle"
var _player: Node2D = null

# Lure handling
var _lure_check_timer := 0.0
var _current_lure: Node = null
var _previous_state: String = "idle"
var _inspect_timer := 0.0

@export var death_alert_radius := 240.0
@export var death_alert_requires_los := true
@export var los_collision_mask: int = 1 # walls/level mask
@export var search_time := 3.0
@export var search_arrive_distance := 12.0

var _search_pos: Vector2 = Vector2.ZERO
var _search_timer := 0.0

func _ready() -> void:
	add_to_group("target")

	_agent.path_desired_distance = 6.0
	_agent.target_desired_distance = 8.0
	_agent.avoidance_enabled = false
	_agent.max_speed = max(chase_speed, lure_speed)
	
	_build_patrol_points()
	if _patrol_points.size() > 0:
		_state = "patrol"
		_set_next_patrol_target()


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
		
	# periodic dead-body scanning
	_body_scan_timer -= delta
	if _body_scan_timer <= 0.0:
		_body_scan_timer = body_detect_interval
		_scan_for_dead_bodies()

	match _state:
		"idle":
			velocity = Vector2.ZERO
			_agent.set_target_position(global_position) # clear path

		"patrol":
			if _patrol_wait_t > 0.0:
				_patrol_wait_t -= delta
				velocity = Vector2.ZERO
			else:
				velocity = _steer_along_path(_current_speed())
				if _agent.is_target_reached():
					_patrol_wait_t = patrol_wait
					_advance_patrol_point()

		"chase":
			if is_instance_valid(_player):
				_agent.set_target_position(_player.global_position)
				velocity = _steer_along_path(_current_speed())
				if _agent.is_target_reached():
					var dir := (_player.global_position - global_position).normalized()
					velocity = dir * chase_speed
			else:
				_state = "idle"

		"lured":
			if is_instance_valid(_current_lure):
				_agent.set_target_position(_current_lure.get_position())
				velocity = _steer_along_path(_current_speed())
			else:
				_state = _previous_state

		"search":
			_agent.set_target_position(_search_pos)
			velocity = _steer_along_path(lure_speed)
			_search_timer -= delta

			var reached := _agent.is_target_reached() or global_position.distance_to(_search_pos) <= search_arrive_distance

			# If we are searching for a specific body, confirm when close enough
			if is_instance_valid(_current_body):
				_search_pos = _current_body.global_position # track if it moves
				if global_position.distance_to(_current_body.global_position) <= body_confirm_distance:
					_known_bodies[_current_body.get_instance_id()] = true
					_current_body = null
					velocity = Vector2.ZERO
					_state = "idle"
					GameManager.player_died("Dead Body found by Guard")
					return

			if reached or _search_timer <= 0.0:
				_current_body = null
				velocity = Vector2.ZERO
				_state = "idle"

	move_and_slide()

	# ensure lure arrival/inspect still runs
	if _state == "lured":
		_process_lured_state(delta)

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

func _on_teammate_killed(at_pos: Vector2) -> void:
	if not _alive:
		return
	# cancel lure if any
	_current_lure = null
	# enter search
	_search_pos = at_pos
	_search_timer = search_time
	_state = "search"

func _has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
	# If basically the same point, treat as visible
	if from_pos.distance_to(to_pos) < 0.5:
		return true

	var space := get_world_2d().direct_space_state

	# Nudge the start forward so the ray does not start *inside* our own collider
	var dir := to_pos - from_pos
	var start := from_pos + dir.normalized() * 2.0

	var q := PhysicsRayQueryParameters2D.create(start, to_pos)
	q.collision_mask = los_collision_mask          # make sure this matches your walls
	q.exclude = [self]                              # never hit ourselves
	q.collide_with_bodies = true                    # StaticBody2D / TileMap bodies
	q.collide_with_areas = true                     # if you use Areas as blockers

	var hit := space.intersect_ray(q)               # Dictionary in Godot 4
	return hit.is_empty()                           # empty => no blocker => LOS true


func _broadcast_death_event() -> void:
	for n in get_tree().get_nodes_in_group("target"):
		if n == self: continue
		# Call a generic ping; each receiver will decide to react or ignore
		if n.has_method("_on_teammate_down_ping"):
			n.call_deferred("_on_teammate_down_ping", global_position)

func _on_teammate_down_ping(at_pos: Vector2) -> void:
	if not _alive:
		return
	# distance check (typed, no unknowns)
	var dist: float = global_position.distance_to(at_pos)
	if dist > death_alert_radius:
		return
	# optional LOS
	if death_alert_requires_los and not _has_line_of_sight(global_position, at_pos):
		return
	_on_teammate_killed(at_pos)  # your existing reaction


func die() -> void:
	if not _alive:
		return

	_broadcast_death_event()

	_alive = false
	remove_from_group("target")
	add_to_group("dead_body")

	# stop AI movement + physics
	set_physics_process(false)
	velocity = Vector2.ZERO

	# disable collisions so it doesn't block nav / player
	set_collision_layer(0)
	set_collision_mask(0)

	if has_node("NavigationAgent2D"):
		$NavigationAgent2D.set_target_position(global_position)

	# Optional: play animation, then just "stay"
	if has_node("AnimatedSprite2D"):
		var anim := $AnimatedSprite2D
		if "die" in anim.sprite_frames.get_animation_names():
			anim.play("die")

	
func _build_patrol_points() -> void:
	_patrol_points.clear()
	if patrol_path == null or patrol_path.curve == null:
		return

	var c := patrol_path.curve
	var len := c.get_baked_length()
	if len <= 1.0:
		return

	var d := 0.0
	while d <= len:
		var p_local := c.sample_baked(d)                 # local to Path2D
		var p_world := patrol_path.to_global(p_local)    # convert to world
		_patrol_points.append(p_world)
		d += patrol_point_spacing

func _set_next_patrol_target() -> void:
	if _patrol_points.size() == 0:
		_state = "idle"
		return
	_agent.set_target_position(_patrol_points[_patrol_i])

func _advance_patrol_point() -> void:
	if _patrol_points.size() == 0:
		return

	_patrol_i += 1
	if _patrol_i >= _patrol_points.size():
		if patrol_loop:
			_patrol_i = 0
		else:
			_patrol_i = _patrol_points.size() - 1

	_set_next_patrol_target()

func _scan_for_dead_bodies() -> void:
	if not _alive:
		return
	# Don't interrupt chase/lured unless you want that behavior
	if _state == "chase" or _state == "lured":
		return

	var best: Node2D = null
	var best_d := INF

	for b in get_tree().get_nodes_in_group("dead_body"):
		if not is_instance_valid(b):
			continue
		if not (b is Node2D):
			continue

		var id := b.get_instance_id()
		if _known_bodies.has(id):
			continue

		var d := global_position.distance_to(b.global_position)
		if d > body_detect_radius:
			continue

		if death_alert_requires_los and not _has_line_of_sight(global_position, b.global_position):
			continue

		if d < best_d:
			best = b
			best_d = d

	if best:
		_on_dead_body_spotted(best)


func _on_dead_body_spotted(body: Node2D) -> void:
	_current_lure = null
	_current_body = body
	_search_pos = body.global_position
	_search_timer = search_time
	_state = "search"
