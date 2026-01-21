extends Area2D

func _ready() -> void:
	monitoring = true

func _on_body_entered(body: Node) -> void:
	if body and (body.is_in_group("player") or body.name == "Player") and _all_enemies_dead():
		GameManager.level_completed()


func _all_enemies_dead() -> bool:
	return get_tree().get_nodes_in_group("target").is_empty()
