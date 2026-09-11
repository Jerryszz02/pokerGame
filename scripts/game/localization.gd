class_name GameLocalization
extends RefCounted

const SYSTEM := "system"
const ZH_CN := "zh_CN"
const EN := "en"
const ALLOWED := [SYSTEM, ZH_CN, EN]

static func system_locale() -> String:
	return locale_for(OS.get_locale())

static func locale_for(locale: String) -> String:
	return ZH_CN if locale.to_lower().begins_with("zh") else EN

static func normalize_choice(value: Variant) -> String:
	var choice := str(value)
	return choice if ALLOWED.has(choice) else SYSTEM

static func apply_choice(value: Variant) -> String:
	var choice := normalize_choice(value)
	TranslationServer.set_locale(system_locale() if choice == SYSTEM else choice)
	return choice

static func choice_label(value: Variant) -> String:
	match normalize_choice(value):
		SYSTEM: return "System / 跟随系统"
		ZH_CN: return "简体中文"
		_: return "English"

static func present(text: String) -> String:
	return TranslationServer.translate(text)

const MESSAGE_SHAPES := [
  {
    "pattern": "^第\\ ([+-]?\\d+)\\ 手牌开始。$",
    "key": "第 %d 手牌开始。",
    "types": [
      "d"
    ]
  },
  {
    "pattern": "^(.*?)\\ 庄位在\\ (.*?)。$",
    "key": "%s 庄位在 %s。",
    "types": [
      "s",
      "s"
    ]
  },
  {
    "pattern": "^轮到\\ (.*?)$",
    "key": "轮到 %s",
    "types": [
      "s"
    ]
  },
  {
    "pattern": "^(.*?)\\ 支付盲注\\ ([+-]?\\d+)。$",
    "key": "%s 支付盲注 %d。",
    "types": [
      "s",
      "d"
    ]
  },
  {
    "pattern": "^已发(.*?)。$",
    "key": "已发%s。",
    "types": [
      "s"
    ]
  },
  {
    "pattern": "^(.*?)\\ 公共牌现在有\\ ([+-]?\\d+)\\ 张。$",
    "key": "%s 公共牌现在有 %d 张。",
    "types": [
      "s",
      "d"
    ]
  },
  {
    "pattern": "^全下后自动发牌，公共牌现在有\\ ([+-]?\\d+)\\ 张。$",
    "key": "全下后自动发牌，公共牌现在有 %d 张。",
    "types": [
      "d"
    ]
  },
  {
    "pattern": "^全下后发(.*?)$",
    "key": "全下后发%s",
    "types": [
      "s"
    ]
  },
  {
    "pattern": "^(.*?)\\ 无人跟注，赢得\\ ([+-]?\\d+)。$",
    "key": "%s 无人跟注，赢得 %d。",
    "types": [
      "s",
      "d"
    ]
  },
  {
    "pattern": "^(.*?)\\ 收回未被跟注的\\ ([+-]?\\d+)。$",
    "key": "%s 收回未被跟注的 %d。",
    "types": [
      "s",
      "d"
    ]
  },
  {
    "pattern": "^返还\\ (.*?)\\ 未被跟注的\\ ([+-]?\\d+)$",
    "key": "返还 %s 未被跟注的 %d",
    "types": [
      "s",
      "d"
    ]
  },
  {
    "pattern": "^(.*?)\\ 用(.*?)赢得\\ ([+-]?\\d+)。$",
    "key": "%s 用%s赢得 %d。",
    "types": [
      "s",
      "s",
      "d"
    ]
  },
  {
    "pattern": "^(.*?)\\ 摊牌：(.*?)。$",
    "key": "%s 摊牌：%s。",
    "types": [
      "s",
      "s"
    ]
  },
  {
    "pattern": "^跟注到\\ ([+-]?\\d+)$",
    "key": "跟注到 %d",
    "types": [
      "d"
    ]
  },
  {
    "pattern": "^加注到\\ ([+-]?\\d+)$",
    "key": "加注到 %d",
    "types": [
      "d"
    ]
  },
  {
    "pattern": "^全下到\\ ([+-]?\\d+)$",
    "key": "全下到 %d",
    "types": [
      "d"
    ]
  },
  {
    "pattern": "^(.*?)\\ 赢得牌局$",
    "key": "%s 赢得牌局",
    "types": [
      "s"
    ]
  },
  {
    "pattern": "^(.*?)。总手数\\ ([+-]?\\d+)，最终筹码\\ ([+-]?\\d+)。$",
    "key": "%s。总手数 %d，最终筹码 %d。",
    "types": [
      "s",
      "d",
      "d"
    ]
  }
]

static func message(text: String, depth: int = 0) -> String:
	if not TranslationServer.get_locale().begins_with(EN) or depth > 5:
		return text
	var exact := present(text)
	if exact != text:
		return exact
	# Only the engine's complete action sentence shape is recognized. Arbitrary
	# player text and unknown historical records are left untouched.
	var action := RegEx.new()
	action.compile("^(.+) (弃牌|让牌|跟注到 [0-9]+|加注到 [0-9]+|全下到 [0-9]+)(?:（(.*)）)?。?$")
	var found := action.search(text)
	if found != null:
		var actor := present("你") if found.get_string(1) == "你" else found.get_string(1)
		var result := actor + " " + message(found.get_string(2), depth + 1)
		if not found.get_string(3).is_empty():
			result += " (" + present(found.get_string(3)) + ")"
		return result + "."
	for shape in MESSAGE_SHAPES:
		var regex := RegEx.new()
		regex.compile(shape.pattern)
		var matched := regex.search(text)
		if matched == null:
			continue
		var values := []
		for i in range(shape.types.size()):
			var value := matched.get_string(i + 1)
			values.append(int(value) if shape.types[i] == "d" else message(value, depth + 1))
		return present(shape.key) % values
	return text
