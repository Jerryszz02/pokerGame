class_name CoachCancellation
extends RefCounted
## Cooperative cancellation token for a running finite search.
##
## A main-thread cancel() may race a worker thread polling is_cancelled()
## during rollout, so every access is mutex-protected. A cancelled search
## returns unavailable diagnostics and never partial advice.

var _mutex := Mutex.new()
var _cancelled := false

func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()

func is_cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value
