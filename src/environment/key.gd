extends Area2D

# String identifier used to match doors. Example: "red", "blue", "green".
@export var key_id: String = "red"

# Tint for the key visual.
@export var key_color: Color = Color(1, 0, 0)

@export var pickup_sound: AudioStream

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sync_visual()


func _sync_visual() -> void:
	if is_instance_valid(sprite):
		sprite.modulate = key_color


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("add_key"):
		body.call("add_key", key_id)

	# Optional one-shot pickup sound
	if pickup_sound != null:
		var p := AudioStreamPlayer2D.new()
		add_child(p)
		p.stream = pickup_sound
		p.finished.connect(func(): p.queue_free())
		p.play()

	queue_free()
