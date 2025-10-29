extends Area2D

func _ready() -> void:
	monitoring = true

func _on_body_entered(body: Node) -> void:
	if body and (body.is_in_group("player") or body.name == "Player"):
		GameManager.level_completed()
