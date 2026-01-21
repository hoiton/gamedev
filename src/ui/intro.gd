extends Control

@export var next_scene_path := "res://levels/level1.tscn"

@export var lines: PackedStringArray = [
	"Good morning, Agent 69.",
	"Your destination is a private estate on the outskirts of the city.",
	"The client has requested a quiet resolution.",
	"Intel suggests multiple civillians on site.",
	"Identify the real target.",
	"Eliminate them.",
	"I will leave you to prepare."
]

@export var chars_per_second := 20.0
@export var hold_seconds := 1.5
# One audio per line (same order as lines)
@export var voice_lines: Array[AudioStream] = []

@onready var line_label: Label = $LineLabel
@onready var voice: AudioStreamPlayer2D = $Voice

var _line_i := 0
var _char_i := 0
var _char_accum := 0.0
var _holding := false
var _hold_t := 0.0

func _ready() -> void:
	_start_line()

func _process(delta: float) -> void:
	# Skip: finish typing, or go next if already finished
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
		if _line_i < lines.size() and not _holding and _char_i < lines[_line_i].length():
			_char_i = lines[_line_i].length()
			line_label.text = lines[_line_i]
			_holding = true
			_hold_t = 0.0
		else:
			voice.stop()
			_next_line()
		return

	if _line_i >= lines.size():
		return

	if not _holding:
		_char_accum += delta * chars_per_second
		var add := int(_char_accum)
		if add > 0:
			_char_accum -= float(add)
			_char_i = min(_char_i + add, lines[_line_i].length())
			line_label.text = lines[_line_i].substr(0, _char_i)

			if _char_i >= lines[_line_i].length():
				_holding = true
				_hold_t = 0.0
	else:
		_hold_t += delta
		if _hold_t >= hold_seconds:
			_next_line()

func _start_line() -> void:
	if _line_i >= lines.size():
		get_tree().change_scene_to_file(next_scene_path)
		return

	_char_i = 0
	_char_accum = 0.0
	_holding = false
	_hold_t = 0.0
	line_label.text = ""

	_play_voice_for_line(_line_i)

func _next_line() -> void:
	_line_i += 1
	_start_line()

func _play_voice_for_line(i: int) -> void:
	if voice_lines.size() <= i:
		return
	var stream := voice_lines[i]
	if stream == null:
		return
	voice.stop()
	voice.stream = stream
	voice.play()
