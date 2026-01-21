extends Node

@export var first_level_path: String = "res://ui/Intro.tscn"
@export var second_level_path: String = "res://levels/level2.tscn"
@export var third_level_path: String = "res://levels/level3.tscn"
var last_level_completed := false
var last_death_reason := ""

var current_level = first_level_path

func _ready() -> void:
	ResourceLoader.load_threaded_request(current_level)

func start_game() -> void:
	last_level_completed = false
	last_death_reason = ""
	get_tree().change_scene_to_file(current_level)

func back_to_menu() -> void:
	current_level = first_level_path
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func player_died(reason: String="") -> void:
	last_death_reason = reason
	get_tree().change_scene_to_file("res://ui/game_over.tscn")

func next_level() -> void:
	if current_level == first_level_path:
		current_level = second_level_path
	elif current_level == second_level_path:
		current_level = third_level_path
	
	start_game()

func level_completed() -> void:
	if current_level == third_level_path:
		last_level_completed = true
		get_tree().change_scene_to_file("res://ui/victory.tscn")
		return
	
	get_tree().change_scene_to_file("res://ui/level_complete.tscn")

func retry_level() -> void:
	start_game()
