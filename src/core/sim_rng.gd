class_name SimRng
extends RefCounted
## The core's seeded random number generator: xoshiro128** with a 128-bit state.
##
## We own the algorithm instead of using Godot's RandomNumberGenerator, whose
## docs say its algorithm "is an implementation detail and should not be
## depended upon". The same seed must give the same values on every platform
## and engine version, so that a save replays the same way. See ADR-0006.
##
## All math stays in 32 bits inside GDScript's 64-bit int, so no operation
## overflows.

const _MASK32 := 0xFFFFFFFF
## The most values that [method randi_range] can choose from.
const MAX_RANGE := 1 << 31

var _s0: int
var _s1: int
var _s2: int
var _s3: int


func _init(p_seed: int = 0) -> void:
	var lo := p_seed & _MASK32
	var hi := (p_seed >> 32) & _MASK32
	var x := lo
	x = _splitmix32_advance(x)
	_s0 = _splitmix32_mix(x)
	x = _splitmix32_advance(x)
	_s1 = _splitmix32_mix(x)
	x = _splitmix32_advance(x ^ hi)
	_s2 = _splitmix32_mix(x)
	x = _splitmix32_advance(x)
	_s3 = _splitmix32_mix(x)
	if _s0 == 0 and _s1 == 0 and _s2 == 0 and _s3 == 0:
		_s0 = 1


## Returns the next value in [0, 2^32).
func next_u32() -> int:
	var result := _mul32(_rotl(_mul32(_s1, 5), 7), 9)
	var t := (_s1 << 9) & _MASK32
	_s2 ^= _s0
	_s3 ^= _s1
	_s1 ^= _s2
	_s0 ^= _s3
	_s2 ^= t
	_s3 = _rotl(_s3, 11)
	return result


## Returns a float in [0, 1).
func randf() -> float:
	return next_u32() / 4294967296.0


## Returns an int in [from, to], both ends included. The range can hold at most
## 2^31 values.
func randi_range(from: int, to: int) -> int:
	var count := to - from + 1
	assert(count > 0 and count <= MAX_RANGE, "randi_range needs 1 to 2^31 values")
	return from + ((next_u32() * count) >> 32)


## The full state, for saves. Restore it with [method set_state].
func get_state() -> PackedInt64Array:
	return PackedInt64Array([_s0, _s1, _s2, _s3])


func set_state(state: PackedInt64Array) -> void:
	assert(state.size() == 4, "SimRng state has 4 words")
	_s0 = state[0] & _MASK32
	_s1 = state[1] & _MASK32
	_s2 = state[2] & _MASK32
	_s3 = state[3] & _MASK32


static func _rotl(x: int, k: int) -> int:
	return ((x << k) | (x >> (32 - k))) & _MASK32


## 32-bit multiply that keeps only the low 32 bits, with no 64-bit overflow.
static func _mul32(a: int, b: int) -> int:
	var low := (a & 0xFFFF) * b
	var high := (((a >> 16) * b) & 0xFFFF) << 16
	return (low + high) & _MASK32


static func _splitmix32_advance(x: int) -> int:
	return (x + 0x9E3779B9) & _MASK32


static func _splitmix32_mix(x: int) -> int:
	var z := x
	z = _mul32(z ^ (z >> 16), 0x85EBCA6B)
	z = _mul32(z ^ (z >> 13), 0xC2B2AE35)
	return z ^ (z >> 16)
