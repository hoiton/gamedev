class_name CoinThrow
extends Area2D

@export var speed: float = 520.0
@export var arrive_epsilon: float = 8.0
@export var max_time: float = 2.0

var _target: Vector2
var _elapsed := 0.0

const LureScene := preload("res://environment/lure.tscn")

func launch(from: Vector2, to: Vector2) -> void:
	# Make sure we ignore any parent transforms entirely
	top_level = true
	global_position = from
	_target = to
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > max_time:
		_land()
		return

	var to_target := _target - global_position
	var dist := to_target.length()

	if dist <= arrive_epsilon:
		_land()
		return

	if dist > 0.0:
		var dir := to_target / dist  # normalized
		global_position += dir * speed * delta
		
func _land() -> void:
	var lure := LureScene.instantiate()
	get_tree().current_scene.add_child(lure)
	lure.global_position = global_position
	queue_free()
