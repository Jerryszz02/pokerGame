class_name CoachService
extends RefCounted
## Only copied data enters the worker. Owners poll on their main-thread tick;
## no deferred busy loop, scene access or file IO runs on the worker thread.
signal completed(token: int, result: Dictionary)
signal style_completed(token: int, result: Dictionary)
var _thread: Thread
var _generation := 0
var _token := 0
var _kind := ""
var _cancellation: CoachCancellation

func request_live(context: Dictionary, options: Dictionary = {}) -> int: return _start("live",context,{},options)
func request_review(context: Dictionary, actual: Dictionary, options: Dictionary = {}) -> int: return _start("review",context,actual,options)
func request_style(record: Dictionary, options: Dictionary = {}) -> int: return _start("style",record,{},options)
func is_busy() -> bool: return _thread != null
func cancel() -> void:
	_generation += 1
	if _cancellation != null: _cancellation.cancel()
func poll() -> void:
	if _thread == null or _thread.is_alive(): return
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	if _token != _generation: return
	if _kind == "style": style_completed.emit(_token,result)
	else: completed.emit(_token,result)
func finish() -> void:
	cancel()
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
func _start(kind: String, context: Dictionary, actual: Dictionary, options: Dictionary) -> int:
	poll()
	if _thread != null: return -1
	_generation += 1
	_token = _generation
	_kind = kind
	_cancellation = CoachCancellation.new()
	var settings := options.duplicate(true)
	settings.cancellation = _cancellation
	_thread = Thread.new()
	if _thread.start(_run.bind(kind,context.duplicate(true),actual.duplicate(true),settings)) != OK:
		_thread = null
		return -1
	return _token
static func _run(kind: String, context: Dictionary, actual: Dictionary, options: Dictionary) -> Dictionary:
	if kind == "live": return CoachAnalysis.live(context,options)
	if kind == "review": return CoachAnalysis.review(context,actual,options)
	return _style_for_record(context,options)
static func _style_for_record(record: Dictionary, options: Dictionary) -> Dictionary:
	var estimates := {}
	var deadline := Time.get_ticks_msec() + 6000
	var frames: Array = record.get("frames",[])
	for index in range(frames.size()):
		if FiniteSearch._is_cancelled(options.get("cancellation")): return {"available":false,"reason":"cancelled"}
		var frame: Dictionary = frames[index]
		if frame.get("action",{}).get("actor",-1) != 0 or not frame.get("decision_context") is Dictionary: continue
		if Time.get_ticks_msec() > deadline: break
		var settings := options.duplicate()
		settings.seed = int(options.get("seed",9173)) + index
		settings.max_worlds = clampi(int(options.get("max_worlds",64)),8,128)
		settings.time_budget_ms = mini(1000,maxi(1,deadline-Time.get_ticks_msec()))
		estimates[index] = CoachAnalysis.live(frame.decision_context,settings)
	var style := PlayerStyle.from_record(record,estimates)
	var luck := AllInLuck.calculate(record,options)
	if FiniteSearch._is_cancelled(options.get("cancellation")): return {"available":false,"reason":"cancelled"}
	if luck.qualifying:
		style.raw.luck_hands = 1
		style.raw.luck_variable_hands = int(luck.variance_bb2 > 0)
		style.raw.luck_delta = luck.delta_bb
		style.raw.luck_variance = luck.variance_bb2
		style = PlayerStyle._finalize(style.raw)
	return {"available":true,"style":style}
