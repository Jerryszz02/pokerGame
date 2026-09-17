class_name RadarChart
extends Control

const DIMENSIONS := ["luck", "aggression", "defense", "risk", "vpip", "pressure"]
const LABELS_ZH := {"luck":"运气", "aggression":"进攻", "defense":"防守", "risk":"冒险", "vpip":"入池", "pressure":"施压"}
const LABELS_EN := {"luck":"Luck", "aggression":"Aggression", "defense":"Defense", "risk":"Risk", "vpip":"VPIP", "pressure":"Pressure"}
const BRASS := Color(0.795, 0.630, 0.300)
const GRID := Color(0.795, 0.630, 0.300, 0.26)
const FILL := Color(0.34, 0.67, 0.48, 0.32)
var style: Dictionary = {}
var sample_counts: Dictionary = {}
var radius := 92.0

func _init() -> void:
	custom_minimum_size = Vector2(260, 240)

func set_style(value: Dictionary) -> void:
	style = value.duplicate(true)
	sample_counts = style.get("counts", {}).duplicate(true)
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5 + Vector2(0, 8)
	var r := minf(radius, minf(size.x, size.y) * 0.34)
	for level in range(1, 4):
		var ring := PackedVector2Array()
		for i in range(6): ring.append(center + _axis(i) * r * float(level) / 3.0)
		ring.append(ring[0])
		draw_polyline(ring, GRID, 1.0, true)
	for i in range(6):
		var end := center + _axis(i) * r
		draw_line(center, end, GRID, 1.0, true)
		var label: String = str((LABELS_EN if TranslationServer.get_locale().begins_with("en") else LABELS_ZH)[DIMENSIONS[i]])
		var pos := center + _axis(i) * (r + 20.0) - Vector2(48, 0)
		draw_string(get_theme_default_font(), pos, label, HORIZONTAL_ALIGNMENT_CENTER, 96, 14, BRASS)
	var values: Dictionary = style.get("dimensions", {})
	var points := PackedVector2Array()
	var available := 0
	for i in range(6):
		var value: Variant = values.get(DIMENSIONS[i], null)
		if value == null: points.append(center); continue
		available += 1
		points.append(center + _axis(i) * r * clampf(float(value), 0.0, 1.0))
	if available == 6:
		var polygon := points.duplicate()
		polygon.append(points[0])
		draw_colored_polygon(points, FILL)
		draw_polyline(polygon, BRASS, 2.0, true)
	else:
		for point in points:
			if point != center: draw_line(center, point, BRASS, 2.0, true)
	for i in range(points.size()):
		if values.get(DIMENSIONS[i]) != null: draw_circle(points[i], 3.0, BRASS)

func _axis(index: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(index) / 6.0
	return Vector2(cos(angle), sin(angle))
