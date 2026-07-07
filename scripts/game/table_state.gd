class_name TableState
extends RefCounted

const INITIAL_STACK = 1000
const SMALL_BLIND = 10
const BIG_BLIND = 20

const STATUS_ACTIVE = "active"
const STATUS_FOLDED = "folded"
const STATUS_ALL_IN = "all_in"
const STATUS_OUT = "out"

const STAGE_PREFLOP = "preflop"
const STAGE_FLOP = "flop"
const STAGE_TURN = "turn"
const STAGE_RIVER = "river"
const STAGE_SHOWDOWN = "showdown"
const STAGE_HAND_OVER = "hand_over"

const ACTION_FOLD = "fold"
const ACTION_CHECK = "check"
const ACTION_CALL = "call"
const ACTION_RAISE = "raise"
const ACTION_ALL_IN = "all_in"
