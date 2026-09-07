extends RefCounted
## Built-in offline diagnostic for the exact packaged game.
## No script/path overrides or access to the player profile.
var failures := 0
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run(scene: Node) -> int:
	print("Package self-test: template=", not OS.has_feature("editor"))
	scene.set_process(false)
	scene.profile.settings.sound_enabled = false
	var font: Font = scene.get_theme_font("font")
	_check(font == scene.UI_FONT, "export uses the bundled regular font")
	_check(font.has_char("你".unicode_at(0)) and font.has_char("筹".unicode_at(0)), "export includes Chinese glyphs")
	var help: PopupPanel = scene._show_text_popup("字体检查", "中文筹码", "FontCheck")
	_check(help.get_theme_font("font", "Label") == font, "popup uses the bundled font")
	help.hide()
	help.queue_free()
	for opponents in [1, 3, 5]:
		for difficulty in range(3):
			scene._show_menu()
			scene.ai_count_spin.value = opponents
			scene.difficulty_options.select(difficulty)
			scene._on_start_pressed()
			var steps := 0
			while scene.game.stage != TableState.STAGE_HAND_OVER and steps < 300:
				var actor: int = scene.game.current_player_index
				var decision: Dictionary = AiDecision.decide(scene.game, actor)
				_check(scene.game.apply_action(decision.action_type, int(decision.amount)), "exported rules accept AI action")
				steps += 1
			_check(scene.game.stage == TableState.STAGE_HAND_OVER, "exported hand finishes for %d opponents/difficulty %d" % [opponents, difficulty])
			scene._render_table()
			var before: int = scene.profile.stats.total_hands
			scene._render_table()
			_check(scene.profile.stats.total_hands == before, "render cannot double-count statistics")
			await scene.get_tree().process_frame
			await scene.get_tree().process_frame
	if failures == 0:
		print("Package self-test passed: packaged scene/font, 9 configurations, one-time statistics.")
	return failures
