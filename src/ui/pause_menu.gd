extends CanvasLayer


@onready var continue_btn: Button = $Root/Center/Panel/Margin/VBox/Continue
@onready var menu_btn: Button = $Root/Center/Panel/Margin/VBox/MainMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	visible = false

	continue_btn.pressed.connect(_on_continue)
	menu_btn.pressed.connect(_on_main_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		_resume()
	else:
		_pause()

func _pause() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _on_continue() -> void:
	_resume()

func _on_main_menu() -> void:
	_resume()
	GameManager.back_to_menu()
