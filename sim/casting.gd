const Rooms = preload("res://sim/rooms.gd")
const Night = preload("res://sim/night.gd")

const NEVER := 0
const REASSIGN := 1


static func needs_for(room: String) -> int:
	match room:
		Rooms.SCARE:
			return Night.ACTORS_PER_SCARE
		Rooms.PAIR_SCARE:
			return Night.ACTORS_PER_SCARE * 2
		_:
			return 0


# Anchor pairing: best with worst, second-best with second-worst, so every
# room's mean skill sits near the roster mean (matches the old uniform bonus).
static func auto_assign(layout: Array) -> Dictionary:
	var rooms := []
	var total := 0
	for i in layout.size():
		var need := needs_for(layout[i])
		if need > 0:
			rooms.append(i)
			total += need
	var assignment := { }
	var lo := 0
	var hi := total - 1
	for room_i in rooms:
		var actors := []
		for j in needs_for(layout[room_i]):
			if j % 2 == 0:
				actors.append(lo)
				lo += 1
			else:
				actors.append(hi)
				hi -= 1
		assignment[room_i] = actors
	return assignment


static func resolve(
	layout: Array,
	roster: Array[Dictionary],
	absent: Array,
	policy: int,
) -> Dictionary:
	var headcount := 0
	for room in layout:
		headcount += needs_for(room)
	var assignment := auto_assign(layout)

	var present := { } # room index -> Array of roster indices, absences removed
	for room_i in assignment:
		var here: Array = []
		for actor_i in assignment[room_i]:
			if actor_i < roster.size() and not absent.has(actor_i):
				here.append(actor_i)
		present[room_i] = here

	if policy == REASSIGN:
		fill_from_bench(layout, present, roster, headcount, absent)
		consolidate(layout, present)

	return downgrade(layout, roster, present)


static func fill_from_bench(
	layout: Array,
	present: Dictionary,
	roster: Array[Dictionary],
	headcount: int,
	absent: Array,
) -> void:
	var bench: Array = []
	for i in range(headcount, roster.size()):
		if not absent.has(i):
			bench.append(i)

	var rooms := present.keys()
	rooms.sort()
	rooms.reverse() # latest hole gets the best on-call actor
	for room_i in rooms:
		var need := needs_for(layout[room_i])
		while present[room_i].size() < need and not bench.is_empty():
			present[room_i].append(bench.pop_front())


static func consolidate(layout: Array, present: Dictionary) -> void:
	var half: Array = []
	for room_i in present:
		if layout[room_i] == Rooms.SCARE and present[room_i].size() == 1:
			half.append(room_i)
	half.sort()
	while half.size() >= 2:
		var donor: int = half.pop_front()
		var recipient: int = half.pop_back()
		present[recipient].append(present[donor].pop_back())


static func downgrade(layout: Array, roster: Array[Dictionary], present: Dictionary) -> Dictionary:
	var tonight := layout.duplicate()
	var ceilings: Array = []
	ceilings.resize(tonight.size())
	ceilings.fill(0.0)

	for i in tonight.size():
		var need := needs_for(tonight[i])
		if need == 0:
			continue
		var here: Array = present.get(i, [])
		if here.size() < need:
			if tonight[i] == Rooms.PAIR_SCARE and here.size() >= Night.ACTORS_PER_SCARE:
				tonight[i] = Rooms.SCARE
			else:
				tonight[i] = Rooms.CORRIDOR
		if tonight[i] == Rooms.CORRIDOR:
			continue
		var sum := 0.0
		for a in here:
			sum += roster[a].skill
		ceilings[i] = sum / here.size()
	return { layout = tonight, ceilings = ceilings }
