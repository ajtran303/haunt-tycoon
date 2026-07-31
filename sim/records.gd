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
						tally(actors, scarer).screams += 1
						if partner != -1:
							tally(actors, partner).assists += 1
					else:
						tally(actors, scarer).whiffs += 1

	return { actors = actors, machine = machine, effects = effects }


static func tally(actors: Dictionary, i: int) -> Dictionary:
	if not actors.has(i):
		actors[i] = { screams = 0, assists = 0, whiffs = 0 }
	return actors[i]
