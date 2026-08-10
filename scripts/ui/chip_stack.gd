extends Control

const CELL_WIDTH := 32
const TOP_REGION_Y := 4
const BODY_REGION_Y := 27
const MODULE_X := 4
const TOP_SIZE := Vector2(24, 12)
const BODY_SIZE := Vector2(24, 5)
const LAYER_STEP := 4
const COLUMN_GAP := 4

var atlas: Texture2D
var chip_indices: Array[int] = []
var max_columns := 2
var max_layers := 5
var pixel_scale := 1

func configure(texture: Texture2D, breakdown: Array, columns: int, layers: int, scale_factor: int = 1) -> void:
	atlas = texture
	max_columns = maxi(1, columns)
	max_layers = maxi(1, layers)
	pixel_scale = maxi(1, scale_factor)
	chip_indices.clear()
	for entry in breakdown:
		var count := int(entry.get("count", 0))
		var atlas_index := int(entry.get("atlas_index", 0))
		for _chip in range(count):
			chip_indices.append(atlas_index)
	_compress_to_capacity()
	var column_count := mini(max_columns, maxi(1, ceili(float(chip_indices.size()) / float(max_layers))))
	var visible_layers := mini(max_layers, maxi(1, ceili(float(chip_indices.size()) / float(column_count))))
	custom_minimum_size = Vector2(
		(column_count * int(TOP_SIZE.x) + (column_count - 1) * COLUMN_GAP) * pixel_scale,
		(int(TOP_SIZE.y) + (visible_layers - 1) * LAYER_STEP) * pixel_scale
	)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _compress_to_capacity() -> void:
	var capacity := max_columns * max_layers
	if chip_indices.size() <= capacity:
		return
	var source := chip_indices.duplicate()
	chip_indices.clear()
	for slot in range(capacity):
		var source_index := floori(float(slot) * float(source.size()) / float(capacity))
		chip_indices.append(int(source[mini(source_index, source.size() - 1)]))

func _draw() -> void:
	if atlas == null or chip_indices.is_empty():
		return
	var column_count := mini(max_columns, maxi(1, ceili(float(chip_indices.size()) / float(max_layers))))
	var index := 0
	for column in range(column_count):
		var remaining := chip_indices.size() - index
		var columns_left := column_count - column
		var layer_count := mini(max_layers, ceili(float(remaining) / float(columns_left)))
		var x := float(column * (int(TOP_SIZE.x) + COLUMN_GAP) * pixel_scale)
		for layer in range(layer_count - 1, -1, -1):
			var chip_index := int(chip_indices[index + layer])
			var y := float((layer_count - 1 - layer) * LAYER_STEP * pixel_scale)
			var body_source := Rect2(chip_index * CELL_WIDTH + MODULE_X, BODY_REGION_Y, BODY_SIZE.x, BODY_SIZE.y)
			draw_texture_rect_region(atlas, Rect2(Vector2(x, y + 7 * pixel_scale), BODY_SIZE * pixel_scale), body_source)
		var top_index := int(chip_indices[index + layer_count - 1])
		var top_source := Rect2(top_index * CELL_WIDTH + MODULE_X, TOP_REGION_Y, TOP_SIZE.x, TOP_SIZE.y)
		draw_texture_rect_region(atlas, Rect2(Vector2(x, 0), TOP_SIZE * pixel_scale), top_source)
		index += layer_count
