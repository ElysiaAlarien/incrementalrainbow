extends RefCounted
## Internal to the core. The events of one tick, earliest first, in a binary
## heap. Thus each event costs a small time, not a pass over all links (see
## ADR-0008).
##
## An event is [code][time_ms, kind, order, a, b][/code]. Events happen in
## order of time, then kind, then order. [code]a[/code] and [code]b[/code] are
## for the handler of the kind. The kinds and the meaning of order are
## [method Simulation.tick]'s rules, not this queue's.

var _heap: Array[Array] = []


func is_empty() -> bool:
	return _heap.is_empty()


func push(time_ms: int, kind: int, order: int, a: Variant = null, b: Variant = null) -> void:
	_heap.append([time_ms, kind, order, a, b])
	var i := _heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent := (i - 1) / 2
		if not _before(_heap[i], _heap[parent]):
			break
		_swap(i, parent)
		i = parent


## Removes and returns the earliest event.
func pop() -> Array:
	var top: Array = _heap[0]
	var last: Array = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		var i := 0
		var size := _heap.size()
		while true:
			var child := 2 * i + 1
			if child >= size:
				break
			if child + 1 < size and _before(_heap[child + 1], _heap[child]):
				child += 1
			if not _before(_heap[child], _heap[i]):
				break
			_swap(i, child)
			i = child
	return top


func _swap(i: int, j: int) -> void:
	var held: Array = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = held


static func _before(x: Array, y: Array) -> bool:
	if x[0] != y[0]:
		return x[0] < y[0]
	if x[1] != y[1]:
		return x[1] < y[1]
	return x[2] < y[2]
