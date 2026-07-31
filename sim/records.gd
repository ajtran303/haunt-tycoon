const Rooms = preload("res://sim/rooms.gd")


static func attribute(group_records: Array, board: Dictionary, roster: Array) -> Dictionary:
	var tonight: Array = board.layout
	var present: Dictionary = board.present
	var actors := { } # roster index -> { screams, assists, whiffs }
	var machine := { hits = 0, whiffs = 0 }
	var effects := { hits = 0 }

	for g in group_records.size():
		for e in group_records[g].events:
			match e.kind:
				"anim_hit":
					machine.hits += 1
				"anim_whiff":
					machine.whiffs += 1
				"effect_hit":
					effects.hits += 1
				"hit", "whiff":
					var here: Array = present[e.room]
					var scarer: int
					var partner := -1
					if tonight[e.room] == Rooms.PAIR_SCARE:
						var d: int = g % 2
						var a: int = here[2 * d]
						var b: int = here[2 * d + 1]
						scarer = a if roster[a].skill >= roster[b].skill else b
						partner = b if scarer == a else a
					else:
						scarer = here[g % here.size()]
					if e.kind == "hit":
						var t = tally(actors, scarer)
						t.screams += 1
						t.top = maxf(t.top, e.reaction)
						if partner != -1:
							tally(actors, partner).assists += 1
					else:
						tally(actors, scarer).whiffs += 1

	return { actors = actors, machine = machine, effects = effects }


static func tally(actors: Dictionary, i: int) -> Dictionary:
	if not actors.has(i):
		actors[i] = { screams = 0, assists = 0, whiffs = 0, top = 0.0 }
	return actors[i]


static func digest(
	records: Dictionary,
	group_records: Array,
	board: Dictionary,
	roster: Array,
	night: int,
	sample_rng: RandomNumberGenerator,
) -> void:
	var t := attribute(group_records, board, roster)
	for i in t.actors:
		var c := career(records.careers, i)
		var a: Dictionary = t.actors[i]
		c.screams += a.screams
		c.assists += a.assists
		c.whiffs += a.whiffs
		c.top_scream = maxf(c.top_scream, a.top)
		if a.screams > c.best_screams:
			c.best_screams = a.screams
			c.best_night = night
	for room_i in board.present:
		for actor_i in board.present[room_i]:
			career(records.careers, actor_i).nights_worked += 1
	if group_records.is_empty():
		return
	var g := sample_rng.randi_range(0, group_records.size() - 1)
	records.nights.append(
		{
			night = night,
			type = group_records[g].type,
			satisfaction = group_records[g].satisfaction,
			events = group_records[g].events,
			tonight = board.layout,
		}
	)


static func career(careers: Dictionary, i: int) -> Dictionary:
	if not careers.has(i):
		careers[i] = {
			screams = 0,
			assists = 0,
			whiffs = 0,
			top_scream = 0.0,
			best_night = 0,
			best_screams = 0,
			nights_worked = 0,
		}
	return careers[i]
