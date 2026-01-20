extends Node2D

@export var door_layer: TileMapLayer

# If true: opening = remove tiles (works with ANY door texture automatically)
@export var erase_on_open := false

# If you later want to swap to a specific "open" tile per door tile,
# set erase_on_open = false and use Custom Data on the tiles:
@export var custom_data_open_x := "open_x"
@export var custom_data_open_y := "open_y"
@export var custom_data_open_alt := "open_alt"

@onready var area: Area2D = $Area2D
@onready var shape_node: CollisionShape2D = $Area2D/CollisionShape2D

var _door_cells: Array[Vector2i] = []
var _closed_tiles: Dictionary = {} # cell -> [source_id, atlas_coords, alternative]
var _is_open := false


func _ready() -> void:
	if door_layer == null:
		push_error("DoorProximity: door_layer not set.")
		return
	if shape_node == null or shape_node.shape == null:
		push_error("DoorProximity: Missing CollisionShape2D/shape.")
		return

	_cache_cells_inside_area()

	area.body_entered.connect(_on_enter)
	area.body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_open()


func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_close()


func _cache_cells_inside_area() -> void:
	_door_cells.clear()
	_closed_tiles.clear()

	var world_rect := _get_area_world_rect()
	if world_rect.size == Vector2.ZERO:
		return

	var local_min: Vector2 = door_layer.to_local(world_rect.position)
	var local_max: Vector2 = door_layer.to_local(world_rect.position + world_rect.size)

	var cell_min: Vector2i = door_layer.local_to_map(Vector2(min(local_min.x, local_max.x), min(local_min.y, local_max.y)))
	var cell_max: Vector2i = door_layer.local_to_map(Vector2(max(local_min.x, local_max.x), max(local_min.y, local_max.y)))

	cell_min -= Vector2i(1, 1)
	cell_max += Vector2i(1, 1)

	for y in range(cell_min.y, cell_max.y + 1):
		for x in range(cell_min.x, cell_max.x + 1):
			var cell := Vector2i(x, y)

			var src := door_layer.get_cell_source_id(cell)
			if src == -1:
				continue

			_door_cells.append(cell)
			_closed_tiles[cell] = [
				src,
				door_layer.get_cell_atlas_coords(cell),
				door_layer.get_cell_alternative_tile(cell)
			]


func _open() -> void:
	if _is_open or door_layer == null:
		return
	_is_open = true

	for cell in _door_cells:
		if erase_on_open:
			door_layer.erase_cell(cell)
		else:
			var td: TileData = door_layer.get_cell_tile_data(cell)
			if td == null:
				door_layer.erase_cell(cell)
				continue

			if not td.has_custom_data(custom_data_open_x) or not td.has_custom_data(custom_data_open_y):
				door_layer.erase_cell(cell)
				continue

			var open_x := int(td.get_custom_data(custom_data_open_x))
			var open_y := int(td.get_custom_data(custom_data_open_y))
			var open_alt := 0
			if td.has_custom_data(custom_data_open_alt):
				open_alt = int(td.get_custom_data(custom_data_open_alt))

			var src: int = _closed_tiles[cell][0]
			door_layer.set_cell(cell, src, Vector2i(open_x, open_y), open_alt)


func _close() -> void:
	if not _is_open or door_layer == null:
		return
	_is_open = false

	for cell in _door_cells:
		var d = _closed_tiles.get(cell, null)
		if d == null:
			continue
		door_layer.set_cell(cell, d[0], d[1], d[2])


func _get_area_world_rect() -> Rect2:
	var s := shape_node.shape
	var gt: Transform2D = shape_node.get_global_transform()

	if s is RectangleShape2D:
		var ext := (s as RectangleShape2D).size * 0.5
		var pts = [
			gt * Vector2(-ext.x, -ext.y),
			gt * Vector2( ext.x, -ext.y),
			gt * Vector2( ext.x,  ext.y),
			gt * Vector2(-ext.x,  ext.y),
		]
		return _rect_from_points(pts)

	if s is CircleShape2D:
		var r := (s as CircleShape2D).radius
		var center := gt.origin
		return Rect2(center - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))

	var p := global_position
	return Rect2(p - Vector2(16, 16), Vector2(32, 32))


func _rect_from_points(points: Array) -> Rect2:
	var min_x: float = points[0].x
	var min_y: float = points[0].y
	var max_x: float = points[0].x
	var max_y: float = points[0].y

	for v in points:
		min_x = min(min_x, v.x)
		min_y = min(min_y, v.y)
		max_x = max(max_x, v.x)
		max_y = max(max_y, v.y)

	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)
