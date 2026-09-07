extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_lifecycle_probe.cfg"
	root.add_child(scene)
	scene.set_process(false)
	var baseline := get_processed_tweens().size()
	scene.game.start_new_match(5, "hard")
	for i in range(40):
		scene._render_table()
		await process_frame
		await process_frame
	scene._show_menu()
	for i in range(3):
		await process_frame
	var remaining := get_processed_tweens().size()
	print("Tween lifecycle baseline=%d after 40 table redraws=%d" % [baseline, remaining])
	var failed := remaining > baseline
	if failed:
		push_error("table redraws retain running material tweens after returning to menu")
	scene.queue_free()
	await process_frame
	if not failed:
		print("UI lifecycle probe passed.")
	quit(1 if failed else 0)
