extends Control

func _ready() -> void:
	self.theme = UITheme.build()


func _on_next_level_pressed() -> void:
	GameManager.next_level()


func _on_menu_pressed() -> void:
	GameManager.back_to_menu()
