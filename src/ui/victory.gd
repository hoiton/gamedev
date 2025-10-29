extends Control

func _ready() -> void:
	self.theme = UITheme.build()

func _on_retry_pressed() -> void:
	GameManager.start_game()

func _on_menu_pressed() -> void:
	GameManager.back_to_menu()
