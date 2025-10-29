extends Control

func _ready() -> void:
	self.theme = UITheme.build()
	var label: Label = $Panel/VBoxContainer/Reason
	if label:
		label.text = GameManager.last_death_reason

func _on_retry_pressed() -> void:
	GameManager.retry_level()

func _on_menu_pressed() -> void:
	GameManager.back_to_menu()
