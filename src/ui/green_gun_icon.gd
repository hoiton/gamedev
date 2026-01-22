extends Control

@export var green_texture: Texture2D
@export var red_texture: Texture2D

func _ready() -> void:
	# Set initial icon correctly when the level loads
	_update_icon(GameManager.has_green_guns)

	# React to changes
	if not GameManager.green_guns_changed.is_connected(_update_icon):
		GameManager.green_guns_changed.connect(_update_icon)

func _exit_tree() -> void:
	# Avoid dangling connections if this scene is freed/reloaded
	if GameManager.green_guns_changed.is_connected(_update_icon):
		GameManager.green_guns_changed.disconnect(_update_icon)

func _update_icon(has_green: bool) -> void:
	$TextureRect.texture = green_texture if has_green else red_texture
