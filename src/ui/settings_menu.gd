extends Control

@export var actions_to_show: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"kill", "throw", "lure"
]

@onready var master_slider: HSlider = $Panel/Margin/VBox/Tabs/Audio/MasterRow/HSlider
@onready var music_slider: HSlider = $Panel/Margin/VBox/Tabs/Audio/MusicRow/HSlider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/Tabs/Audio/SFXRow/HSlider

@onready var master_value: Label = $Panel/Margin/VBox/Tabs/Audio/MasterRow/Value
@onready var music_value: Label = $Panel/Margin/VBox/Tabs/Audio/MusicRow/Value
@onready var sfx_value: Label = $Panel/Margin/VBox/Tabs/Audio/SFXRow/Value

@onready var keybind_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Keybinds/MarginContainer/KeybindList
@onready var back_btn: Button = $Panel/Margin/VBox/Buttons/Back
@onready var reset_btn: Button = $Panel/Margin/VBox/Buttons/Reset

# Audio buses (create these in Project Settings > Audio > Buses)
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const CFG_PATH := "user://settings.cfg"

var _waiting_for_rebind_action: String = ""
var _waiting_button: Button = null

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	reset_btn.pressed.connect(_on_reset)

	master_slider.value_changed.connect(func(v): _set_bus_volume(BUS_MASTER, v); _update_slider_labels())
	music_slider.value_changed.connect(func(v): _set_bus_volume(BUS_MUSIC, v); _update_slider_labels())
	sfx_slider.value_changed.connect(func(v): _set_bus_volume(BUS_SFX, v); _update_slider_labels())

	_load_settings()
	_build_keybind_list()
	_update_slider_labels()

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_rebind_action == "":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_apply_rebind(_waiting_for_rebind_action, event)
		_waiting_for_rebind_action = ""
		if is_instance_valid(_waiting_button):
			_waiting_button.text = _format_action_bind(_waiting_button.get_meta("action_name"))
		_waiting_button = null
		_save_settings()
		get_viewport().set_input_as_handled()

func _build_keybind_list() -> void:
	# clear old rows
	for c in keybind_list.get_children():
		c.queue_free()

	for action_name in actions_to_show:
		var row := HBoxContainer.new()

		var lbl := Label.new()
		lbl.text = action_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = _format_action_bind(action_name)
		btn.set_meta("action_name", action_name)
		btn.pressed.connect(func():
			_waiting_for_rebind_action = action_name
			_waiting_button = btn
			btn.text = "Press a key..."
		)
		row.add_child(btn)

		keybind_list.add_child(row)

func _format_action_bind(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Unbound"
	# show first key event (simple + clean)
	for e in events:
		if e is InputEventKey:
			return OS.get_keycode_string(e.keycode)
	return events[0].as_text()

func _apply_rebind(action_name: String, new_event: InputEventKey) -> void:
	# remove existing key binds for this action (keys only)
	var existing := InputMap.action_get_events(action_name)
	for e in existing:
		if e is InputEventKey:
			InputMap.action_erase_event(action_name, e)

	# also prevent duplicates: remove this key from other actions (optional but nice)
	for other in actions_to_show:
		if other == action_name:
			continue
		var other_events := InputMap.action_get_events(other)
		for e in other_events:
			if e is InputEventKey and e.keycode == new_event.keycode:
				InputMap.action_erase_event(other, e)

	InputMap.action_add_event(action_name, new_event)

func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return

	# percent 0..100 -> db
	# 0% = -80db (basically mute), 100% = 0db
	var db := linear_to_db(clampf(percent / 100.0, 0.0001, 1.0))
	AudioServer.set_bus_volume_db(idx, db)

func _get_bus_volume_percent(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 100.0
	var db := AudioServer.get_bus_volume_db(idx)
	var lin := db_to_linear(db)
	return clampf(lin * 100.0, 0.0, 100.0)

func _update_slider_labels() -> void:
	master_value.text = str(int(master_slider.value)) + "%"
	music_value.text = str(int(music_slider.value)) + "%"
	sfx_value.text = str(int(sfx_slider.value)) + "%"

func _on_back() -> void:
	_save_settings()
	GameManager.back_to_menu()

func _on_reset() -> void:
	# Reset volumes
	master_slider.value = 100
	music_slider.value = 100
	sfx_slider.value = 100

	# Reset keybinds: easiest is reload project defaults (requires you to define defaults below)
	_reset_keybinds_to_defaults()
	_build_keybind_list()
	_save_settings()

func _reset_keybinds_to_defaults() -> void:
	# You define your defaults here (example)
	_set_default_key("move_up", KEY_W)
	_set_default_key("move_down", KEY_S)
	_set_default_key("move_left", KEY_A)
	_set_default_key("move_right", KEY_D)
	_set_default_key("kill", KEY_E)
	_set_default_key("throw", KEY_Q)
	_set_default_key("lure", KEY_X)

func _set_default_key(action_name: String, keycode: Key) -> void:
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			InputMap.action_erase_event(action_name, e)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action_name, ev)

func _save_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master", master_slider.value)
	cfg.set_value("audio", "music", music_slider.value)
	cfg.set_value("audio", "sfx", sfx_slider.value)

	# keybinds: store keycodes
	for action_name in actions_to_show:
		var events := InputMap.action_get_events(action_name)
		var keycode := 0
		for e in events:
			if e is InputEventKey:
				keycode = int(e.keycode)
				break
		cfg.set_value("keys", action_name, keycode)

	cfg.save(CFG_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err == OK:
		master_slider.value = float(cfg.get_value("audio", "master", 100.0))
		music_slider.value = float(cfg.get_value("audio", "music", 100.0))
		sfx_slider.value = float(cfg.get_value("audio", "sfx", 100.0))

		_set_bus_volume(BUS_MASTER, master_slider.value)
		_set_bus_volume(BUS_MUSIC, music_slider.value)
		_set_bus_volume(BUS_SFX, sfx_slider.value)

		for action_name in actions_to_show:
			var keycode := int(cfg.get_value("keys", action_name, 0))
			if keycode != 0:
				_apply_rebind(action_name, _make_key_event(keycode))
	else:
		# first run defaults
		master_slider.value = _get_bus_volume_percent(BUS_MASTER)
		music_slider.value = _get_bus_volume_percent(BUS_MUSIC)
		sfx_slider.value = _get_bus_volume_percent(BUS_SFX)

func _make_key_event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	return ev
