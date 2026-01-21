extends Control

@onready var good_job: AudioStreamPlayer2D = $GoodJob

func _ready() -> void:
	good_job.play()
	self.theme = UITheme.build()

func _on_menu_pressed() -> void:
	GameManager.back_to_menu()
