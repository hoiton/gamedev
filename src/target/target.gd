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

@export var is_real_target := false

@export var vision_range := 200.0
@export var vision_fov_deg := 50.0            # total cone angle
@export var vision_check_interval := 0.08     # how often to check
@export var vision_confirm_time := 0.25       # time needed to confirm seeing player
@export var lose_sight_grace := 0.35          # keep "seen" for a short time after losing LOS
@export var vision_segments := 16   # smoothness of cone

@export var player_group := "player"          # or "Player" if that is your group

@export var catch_distance := 18.0          # game over if guard gets this close
@export var lose_chase_time := 1.2          # how long without LOS to stop chasing
@export var search_after_lose := 2.5        # how long to search last seen pos

var _body_scan_timer := 0.0
var _known_bodies := {} # instance_id -> true (avoid re-reacting)
var _current_body: Node2D = null

var _last_seen_player_pos: Vector2 = Vector2.ZERO
var _chase_los_lost_timer := 0.0

var _resume_patrol := false

@onready var _agent: NavigationAgent2D = $NavigationAgent2D
@onready var _vision_cone: Polygon2D = $VisionCone/Polygon2D

var _alive := true
var _state : String = "idle"
var _player: Node2D = null

var _vision_timer := 0.0
var _facing := Vector2.RIGHT
var _see_timer := 0.0
var _lose_timer := 0.0


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
	if is_real_target:
		add_to_group("required_target")
		set_highlight(true)

	_agent.path_desired_distance = 6.0
	_agent.target_desired_distance = 8.0
	_agent.avoidance_enabled = false
	_agent.max_speed = max(chase_speed, lure_speed)
	
	_build_patrol_points()
	if _patrol_points.size() > 0:
		_state = "patrol"
		_set_next_patrol_target()
	
	_build_vision_cone()


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
		
	# periodic vision scan (player)
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = vision_check_interval
		_scan_vision_for_player(vision_check_interval)


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
				# 1) Caught check (close enough => game over)
				if global_position.distance_to(_player.global_position) <= catch_distance:
					GameManager.player_died("Caught by guard")
					return

				# 2) Check if we currently see the player (cone + LOS)
				var sees_now := _can_see_point(_player.global_position)

				if sees_now:
					_last_seen_player_pos = _player.global_position
					_chase_los_lost_timer = 0.0
				else:
					_chase_los_lost_timer += delta

				# 3) Chase target: if we see them, chase them; else go to last seen spot
				var chase_target := _player.global_position if sees_now else _last_seen_player_pos
				_agent.set_target_position(chase_target)
				velocity = _steer_along_path(_current_speed())

				# 4) Lose chase after enough time without LOS
				if _chase_los_lost_timer >= lose_chase_time:
					_search_pos = _last_seen_player_pos
					_search_timer = search_after_lose
					_state = "search"
					_resume_patrol = true
					velocity = Vector2.ZERO

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

				if _resume_patrol and _patrol_points.size() > 0:
					_resume_patrol = false
					_state = "patrol"
					# pick the closest patrol point so it doesn't "snap back"
					_patrol_i = _get_closest_patrol_index()
					_set_next_patrol_target()
				else:
					_resume_patrol = false
					_state = "idle"

	# Update facing direction from movement
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
		$VisionCone.rotation = _facing.angle()

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

func _get_closest_patrol_index() -> int:
	if _patrol_points.size() == 0:
		return 0
	var best_i := 0
	var best_d := INF
	for i in range(_patrol_points.size()):
		var d := global_position.distance_to(_patrol_points[i])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

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

func _is_point_in_cone(point: Vector2) -> bool:
	var to := point - global_position
	var dist := to.length()
	if dist > vision_range:
		return false
	if dist < 0.001:
		return true

	var dir := to / dist
	var f := _facing.normalized()
	var half_fov := deg_to_rad(vision_fov_deg) * 0.5
	var angle := acos(clampf(f.dot(dir), -1.0, 1.0))
	return angle <= half_fov

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
	
	if not is_in_group("required_target"):
		GameManager.lose_green_guns()

	_alive = false
	remove_from_group("target")
	remove_from_group("required_target")
	add_to_group("dead_body")

	if has_node("KillSound"):
		$KillSound.play()
		
	if is_instance_valid(_vision_cone):
		$VisionCone.queue_free()

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

func set_highlight(on: bool) -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = (
			Color(1, 1, 1, 1)
			if not on
			else Color(1.3, 0.7, 0.8, 1)
		)

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

		# Must be inside vision cone
		if not _is_point_in_cone(b.global_position):
			continue

		# Must have LOS (optional)
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
	GameManager.lose_green_guns()


# ------------------------------------------------
# Cone Vision
func _scan_vision_for_player(dt: float) -> void:
	if not _alive or _state == "lured":
		return
	
	# Optional: don't see while dead / lured / etc. Adjust to taste.
	# If you want guards to still see during patrol/search, keep as-is.
	# Example: if _state == "lured": return

	var p := _get_player()
	if not is_instance_valid(p):
		_reset_vision_timers(dt)
		return

	var can_see := _can_see_point(p.global_position)

	if can_see:
		_last_seen_player_pos = p.global_position
		_lose_timer = lose_sight_grace
		_see_timer += dt
		if _see_timer >= vision_confirm_time:
			_on_player_spotted(p)
	else:
		_reset_vision_timers(dt)

func _reset_vision_timers(dt: float) -> void:
	_see_timer = maxf(0.0, _see_timer - dt)

	# grace timer counts down; during grace we keep "memory" but do not increase see timer
	_lose_timer = maxf(0.0, _lose_timer - dt)

func _get_player() -> Node2D:
	# cache if you want, but this is simple and robust.
	# If you already store _player somewhere else, just return that.
	var nodes := get_tree().get_nodes_in_group(player_group)
	if nodes.size() > 0 and nodes[0] is Node2D:
		return nodes[0]
	return null

func _can_see_point(point: Vector2) -> bool:
	var world_scale := _vision_world_scale()
	var actual_range := vision_range * world_scale
	
	var to := point - global_position
	var dist := to.length()
	if dist > actual_range:
		return false
	if dist < 0.001:
		return true

	var dir := to / dist
	var f := _facing.normalized()
	var half_fov := deg_to_rad(vision_fov_deg) * 0.5
	var angle := acos(clampf(f.dot(dir), -1.0, 1.0))
	if angle > half_fov:
		return false

	return _has_line_of_sight(global_position, point)

func _vision_world_scale() -> float:
	# If you scale the whole level uniformly, X and Y should be the same.
	# Use the node that is actually scaled (VisionCone or self).
	return global_transform.get_scale().x

func _on_player_spotted(p: Node2D) -> void:
	_player = p
	_last_seen_player_pos = p.global_position
	_chase_los_lost_timer = 0.0
	_see_timer = 0.0
	_resume_patrol = false
	GameManager.lose_green_guns()

	if _state != "chase":
		_state = "chase"

func _build_vision_cone() -> void:
	if _vision_cone == null:
		return

	var pts: PackedVector2Array = []
	pts.append(Vector2.ZERO)

	var half := deg_to_rad(vision_fov_deg) * 0.5
	for i in range(vision_segments + 1):
		var t := float(i) / vision_segments
		var ang: float = lerp(-half, half, t)
		var p := Vector2.RIGHT.rotated(ang) * vision_range
		pts.append(p)

	_vision_cone.polygon = pts
