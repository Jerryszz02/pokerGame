class_name CoachContext
extends RefCounted
## Thin compatibility facade over the game-owned neutral decision snapshot.
##
## The actual snapshot capture/restore/schema implementation lives in
## `res://scripts/game/decision_snapshot.gd` (DecisionSnapshot) because that
## neutral data belongs to the game layer. This module only forwards for
## existing callers, so saved schema/version/kind and every call site stay
## unchanged and no data migration is needed.

const _Snapshot := preload("res://scripts/game/decision_snapshot.gd")

const VERSION := _Snapshot.VERSION
const KIND := _Snapshot.KIND
const MAX_PLAYERS := _Snapshot.MAX_PLAYERS

const _STATUSES := _Snapshot._STATUSES
const _STAGES := _Snapshot._STAGES
const _REQUIRED_INTS := _Snapshot._REQUIRED_INTS

static func capture(game, hero: int = 0) -> Dictionary:
	return _Snapshot.capture(game, hero)

static func restore(context: Dictionary) -> Variant:
	return _Snapshot.restore(context)

static func _valid_schema(context: Dictionary) -> bool:
	return _Snapshot._valid_schema(context)

static func _is_number(value: Variant) -> bool:
	return _Snapshot._is_number(value)

static func _clone_history(value: Variant) -> Array:
	return _Snapshot._clone_history(value)

static func _parse_cards(value: Variant) -> Variant:
	return _Snapshot._parse_cards(value)

static func _is_int_like(value: Variant) -> bool:
	return _Snapshot._is_int_like(value)

static func _int(value: Variant, fallback: int) -> int:
	return _Snapshot._int(value, fallback)
