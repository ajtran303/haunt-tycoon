const Rooms = preload("res://sim/rooms.gd")

const SALIENCE_MARGIN := 25.0 # rep deviation that makes a night worth talking about
const STANDOUT_SAT := 90.0
const BORE_STRETCH := 2

const VERDICT_HIGH := 75.0
const VERDICT_LOW := 40.0

const VOICE := {
	thrill_seeker = {
		verdict_high = "Okay. THAT one. First haunt this year that got a flinch out of me.",
		verdict_mid = "Decent. Wouldn't line up twice.",
		verdict_low = "I've had scarier bus rides.",
		best_moment = "Room {room} earned the ticket. The rest were warming up.",
		fizzled_ending = "You walk out on a miss. The last room just let us leave.",
		dead_room = "Room {room} is an empty hallway with a ticket price.",
		dead_rooms = "Half the place was empty hallway. Empty. Hallway.",
		bore = "There's a stretch in the middle where nothing happens. At all.",
		whiff = "The scarer in room {room} jumped too early. We just stood there.",
	},
	anxious = {
		verdict_high = "I want to state for the record that I did not cry. My friends are liars.",
		verdict_mid = "It was a lot. It was fine. It was a lot.",
		verdict_low = "Honestly? I was okay the whole time. Which was... nice?",
		best_moment = "Whatever is in room {room}, I'll be seeing it again tonight when I close my eyes.",
		fizzled_ending = "Thank god the last room did nothing. I could not have taken one more.",
		dead_room = "Room {room} was just... a hallway? I braced for nothing.",
		dead_rooms = "So many empty rooms. I kept bracing for nothing.",
		bore = "The long quiet part almost got me to relax. Almost.",
		whiff = "One of them popped out early and apologized with his eyes.",
	},
	skeptic = {
		verdict_high = "I'll allow it. Somebody in there knows what they're doing.",
		verdict_mid = "Competent. Padded, but competent.",
		verdict_low = "Rubber masks and air horns. I called every scare before it happened.",
		best_moment = "Credit where due: room {room} has actual craft in it.",
		fizzled_ending = "And the finale whiffed. You get one job, last room.",
		dead_room = "Room {room}: bare walls. They didn't even dress it.",
		dead_rooms = "Multiple undressed rooms. I counted.",
		bore = "Three hallways in a row. I checked my phone.",
		whiff = "Watched the actor in room {room} blow their cue from a mile off.",
	},
	kid = {
		verdict_high = "My kid screamed, laughed, and demanded to go again. So we're going again.",
		verdict_mid = "Kid had fun. I've paid more for less.",
		verdict_low = "My kid asked when it was going to start. On the way out.",
		best_moment = "Room {room} nearly launched my kid into orbit. Ten out of ten.",
		fizzled_ending = "The ending fell flat and the car ride home was a review I won't repeat.",
		dead_room = "We walked through room {room} wondering if that part was closed.",
		dead_rooms = "Whole stretches were just us, walking. My kid gave up bracing.",
		bore = "There's a long boring bit where my kid started narrating.",
		whiff = "The monster in room {room} missed their moment and my kid waved at him.",
	},
}

const MAX_CLAIM_LINES := 2


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
	rep: float,
	result: Dictionary,
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
	var screams := 0
	var whiffs := 0
	for a in t.actors.values():
		screams += a.screams
		whiffs += a.whiffs
	if result.groups != 0:
		records.box.append(
			{
				night = night,
				screams = screams,
				whiffs = whiffs,
				machine_hits = t.machine.hits,
				machine_whiffs = t.machine.whiffs,
				effect_hits = t.effects.hits,
				actor_hits = roundi(result.real_hit_average * result.groups),
				misses = roundi(result.misses * result.groups),
				hits = roundi(result.hit_average * result.groups),
			}
		)
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
			reputation = rep,
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


static func claims(rec: Dictionary, built: Array) -> Array:
	var out := []
	var best := -1
	var last_scare := -1
	for j in rec.events.size():
		var e: Dictionary = rec.events[j]
		match e.kind:
			"corridor":
				if built[e.room] != Rooms.CORRIDOR:
					out.append({ kind = "dead_room", room = e.room, source = j })
				elif e.bore > 0.0:
					out.append({ kind = "bore", room = e.room, source = j })
			"whiff", "anim_whiff":
				out.append({ kind = "whiff", room = e.room, source = j })
				last_scare = j
			_:
				if best == -1 or e.reaction > rec.events[best].reaction:
					best = j
				last_scare = j
	if best != -1:
		out.append({ kind = "best_moment", room = rec.events[best].room, source = best })
	if last_scare != -1 and rec.events[last_scare].kind in ["whiff", "anim_whiff"]:
		out.append(
			{ kind = "fizzled_ending", room = rec.events[last_scare].room, source = last_scare }
		)
	out.append({ kind = "verdict", room = -1, source = -1 })
	return out


static func salient(rec: Dictionary, claim_list: Array) -> bool:
	if absf(rec.satisfaction - rec.reputation) >= SALIENCE_MARGIN:
		return true
	if rec.satisfaction >= STANDOUT_SAT:
		return true
	var bore_run := 0
	var prev_source := -2
	for c in claim_list:
		match c.kind:
			"fizzled_ending":
				if rec.satisfaction < VERDICT_HIGH:
					return true
			"dead_room":
				return true
			"bore":
				bore_run = bore_run + 1 if c.source == prev_source + 1 else 1
				prev_source = c.source
				if bore_run >= BORE_STRETCH:
					return true
	return false


static func render(rec: Dictionary, claim_list: Array) -> String:
	var v: Dictionary = VOICE[rec.type]
	var dead: Array = []
	var by_kind := { }
	for c in claim_list:
		if c.kind == "dead_room":
			dead.append(c)
		elif not by_kind.has(c.kind):
			by_kind[c.kind] = c # first of each kind wins

	var lines: Array[String] = []
	if rec.satisfaction >= VERDICT_HIGH:
		lines.append(v.verdict_high)
	elif rec.satisfaction < VERDICT_LOW:
		lines.append(v.verdict_low)
	else:
		lines.append(v.verdict_mid)

	var extras: Array[String] = []
	if dead.size() >= 2:
		extras.append(v.dead_rooms)
	elif dead.size() == 1:
		extras.append(v.dead_room.format({ room = dead[0].room + 1 }))
	if by_kind.has("fizzled_ending"):
		extras.append(v.fizzled_ending)
	if by_kind.has("best_moment") and rec.satisfaction >= VERDICT_LOW:
		extras.append(v.best_moment.format({ room = by_kind.best_moment.room + 1 }))
	if by_kind.has("bore"):
		extras.append(v.bore)
	if by_kind.has("whiff"):
		extras.append(v.whiff.format({ room = by_kind.whiff.room + 1 }))

	for i in mini(MAX_CLAIM_LINES, extras.size()):
		lines.append(extras[i])
	return " ".join(lines)
