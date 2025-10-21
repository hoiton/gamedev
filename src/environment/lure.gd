class_name Lure
extends Area2D

@export var attract_radius: float = 160.0
@export var life_time: float = 6.0
@export var inspect_time: float = 1.2
@export var investigate_priority: int = 10  # higher = more attractive

@onready var _life_timer: Timer = $LifeTimer

func _ready() -> void:
	add_to_group("lure")
	_life_timer.wait_time = life_time
	_life_timer.one_shot = true
	_life_timer.start()
	_life_timer.timeout.connect(queue_free)

func get_glob_position() -> Vector2:
	return global_position

func get_inv_priority() -> int:
	return investigate_priority

func get_attract_radius() -> float:
	return attract_radius
