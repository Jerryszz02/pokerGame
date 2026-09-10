extends SceneTree

const Profile := preload("res://scripts/game/local_profile.gd")
const Localization := preload("res://scripts/game/localization.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_catalog()
	_assert(Localization.locale_for("zh_TW") == "zh_CN", "Chinese system locales use available Chinese")
	_assert(Localization.locale_for("en_US") == "en", "English system locale")
	_assert(Localization.locale_for("fr_FR") == "en", "unsupported system languages fall back to English")
	_assert(Localization.normalize_choice("bad") == "system", "invalid language should fall back to system")
	_assert(Localization.normalize_choice(null) == "system", "missing language should default to system")
	var legacy := Profile.normalize_profile({"settings":{"ai_count":2}})
	_assert(legacy.settings.language == "system", "legacy profile should receive automatic language")
	var invalid := Profile.normalize_profile({"settings":{"language":"fr"}})
	_assert(invalid.settings.language == "system", "unsupported language should be normalized")
	Localization.apply_choice("en")
	_assert(tr("设置") == "Settings", "English translation should load")
	_assert(tr("弃牌") == "Fold", "action translation should load")
	Localization.apply_choice("zh_CN")
	_assert(tr("设置") == "设置", "Chinese translation should load")
	_assert(Localization.choice_label("system") == "System / 跟随系统", "language selector should stay bilingual")
	if failures == 0:
		print("Localization tests passed.")
	else:
		push_error("%d localization tests failed." % failures)
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_catalog() -> void:
	var file := FileAccess.open("res://assets/translations/poker.csv", FileAccess.READ)
	file.get_csv_line()
	var placeholders := RegEx.new()
	placeholders.compile("%[+0-9.]*[sdf]")
	var seen := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty(): continue
		_assert(row.size() == 3,"catalog row must contain exactly three quoted CSV fields")
		if row.size() != 3: continue
		_assert(not seen.has(row[0]),"catalog keys must be unique: "+row[0])
		seen[row[0]] = true
		var source := placeholders.search_all(row[0])
		var translated := placeholders.search_all(row[1])
		_assert(source.size() == translated.size(),"placeholder count: "+row[0])
		for i in range(mini(source.size(),translated.size())):
			_assert(source[i].get_string() == translated[i].get_string(),"placeholder order/type: "+row[0])
	Localization.apply_choice("en")
	_assert(Localization.message("你 用同花顺赢得 40。") == "You with Straight flush wins 40.","legacy result localizes without rewriting saved text")
	_assert(Localization.message("a player's own note") == "a player's own note","unknown legacy text must remain unchanged")
	Localization.apply_choice("zh_CN")
	_assert(Localization.message("你 用同花顺赢得 40。") == "你 用同花顺赢得 40。","Chinese stored result remains exact")
