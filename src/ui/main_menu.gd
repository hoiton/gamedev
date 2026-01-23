extends Control

func _ready() -> void:
	self.theme = UITheme.build()

func _on_play_pressed() -> void:
	GameManager.start_game()

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	GameManager.go_to_settings()
