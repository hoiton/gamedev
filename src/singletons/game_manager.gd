extends Node

@export var first_level_path: String = "res://levels/level.tscn"
var last_level_completed := false
var last_death_reason := ""

func _ready() -> void:
	ResourceLoader.load_threaded_request(first_level_path)

func start_game() -> void:
	last_level_completed = false
	last_death_reason = ""
	get_tree().change_scene_to_file(first_level_path)

func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func player_died(reason: String="") -> void:
	last_death_reason = reason
	get_tree().change_scene_to_file("res://ui/game_over.tscn")

func level_completed() -> void:
	last_level_completed = true
	get_tree().change_scene_to_file("res://ui/victory.tscn")

func retry_level() -> void:
	# ToDo: add functioning retry of current level instead of loading first level
	start_game()
