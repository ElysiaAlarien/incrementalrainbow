extends GutTest
## SimRng is the core's seeded random number generator. Its output must never
## change across platforms or engine versions, or old saves would replay
## differently.


func _take(rng: SimRng, count: int) -> Array[int]:
	var values: Array[int] = []
	for i in count:
		values.append(rng.next_u32())
	return values


func test_matches_the_published_xoshiro128_starstar_vectors() -> void:
	var rng := SimRng.new()
	rng.set_state(PackedInt64Array([1, 2, 3, 4]))
	assert_eq(_take(rng, 3), [11520, 0, 5927040] as Array[int])


func test_seeding_gives_known_values() -> void:
	# Golden values from an independent Python reference of the same algorithm.
	assert_eq(_take(SimRng.new(42), 5),
		[2837322924, 544945897, 479756282, 3500138142, 339756180] as Array[int])
	assert_eq(_take(SimRng.new(-1), 3), [835879718, 3894099366, 3348284360] as Array[int])
	assert_eq(_take(SimRng.new(1 << 40), 3), [3809008728, 390529322, 2181702422] as Array[int])


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_take(SimRng.new(7), 20), _take(SimRng.new(7), 20))


func test_different_seeds_give_different_sequences() -> void:
	assert_ne(_take(SimRng.new(7), 5), _take(SimRng.new(8), 5))


func test_restoring_the_state_continues_the_same_sequence() -> void:
	var rng := SimRng.new(99)
	_take(rng, 3)
	var copy := SimRng.new()
	copy.set_state(rng.get_state())
	assert_eq(_take(copy, 10), _take(rng, 10))


func test_randf_stays_in_the_unit_interval() -> void:
	var rng := SimRng.new(5)
	for i in 1000:
		var value := rng.randf()
		assert_true(value >= 0.0 and value < 1.0, "randf gave %s" % value)


func test_randi_range_includes_both_ends_and_nothing_else() -> void:
	var rng := SimRng.new(5)
	var seen := {}
	for i in 1000:
		seen[rng.randi_range(-2, 2)] = true
	var keys := seen.keys()
	keys.sort()
	assert_eq(keys, [-2, -1, 0, 1, 2])
