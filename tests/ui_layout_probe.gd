extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		await _probe_table_layout(viewport_size)
	if failures == 0:
		print("All UI layout probes passed.")
	else:
		push_error("%d UI layout probes failed." % failures)
	quit(failures)

func _probe_table_layout(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_control.size = Vector2(viewport_size)
	scene.game.start_new_match(5, "hard")
	scene._render_table()
	await process_frame
	await process_frame

	var frame := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var table_root: Control = scene.get_child(1)
	var root_ratio := table_root.size.x / float(viewport_size.x)
	_assert(root_ratio >= 0.70 and root_ratio <= 0.94, "%s root width ratio %.3f should be within 70%%-94%%" % [viewport_size, root_ratio])
	_assert(_controls_fit(scene, frame), "%s visible controls should stay inside viewport" % viewport_size)
	scene.queue_free()
	await process_frame

func _controls_fit(node: Node, frame: Rect2) -> bool:
	if node is Control and node.visible:
		var rect: Rect2 = node.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			var min_ok := rect.position.x >= -1.0 and rect.position.y >= -1.0
			var max_ok := rect.end.x <= frame.size.x + 1.0 and rect.end.y <= frame.size.y + 1.0
			if not min_ok or not max_ok:
				push_error("%s out of bounds: %s in %s" % [node.name, rect, frame])
				return false
	for child in node.get_children():
		if not _controls_fit(child, frame):
			return false
	return true

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
