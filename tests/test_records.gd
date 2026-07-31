extends SceneTree

const Walkthrough = preload("res://sim/walkthrough.gd")
const Rooms = preload("res://sim/rooms.gd")
const Casting = preload("res://sim/casting.gd")
const Night = preload("res://sim/night.gd")
const Records = preload("res://sim/records.gd")
const Allocation = preload("res://sim/allocation.gd")

const LAYOUT := ["a", "g", "e", "g", "g", "p", "n", "g", "g", "a"]
const SEED := 12345
const SEEDS := 20

const BUILD_HEAVY := { build = 23_000.0, quality = 0.0, depth = 0.0, marketing = 1_000.0 }
const CAST_HEAVY := { build = 9_500.0, quality = 14_000.0, depth = 5_000.0, marketing = 1_000.0 }

var failed := 0


func _initialize() -> void:
	events_resum()
	collector_changes_nothing()
	night_conservation()
	season_collector_changes_nothing()
	quiet_night_no_card()
	claims_are_honest()
	full_season_conservation()
	print("PASS: records invariants hold" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


func events_resum() -> void:
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + s
		var events: Array = []
		var w: Dictionary = Walkthrough.run(
			LAYOUT,
			rng,
			Walkthrough.RECOVERY,
			Walkthrough.DEFAULT_CEILING,
			Walkthrough.PRIME_SCALE,
			Walkthrough.DEFAULT_TANK,
			1.0,
			[],
			events,
		)
		var counts := {
			hit = 0,
			whiff = 0,
			anim_hit = 0,
			anim_whiff = 0,
			effect_hit = 0,
			corridor = 0,
		}
		var bore := 0.0
		var top := 0.0
		for e in events:
			counts[e.kind] += 1
			bore += e.bore
			top = maxf(top, e.reaction)
		check(
			events.size() == LAYOUT.size(),
			"seed %d: %d events for %d rooms" % [SEED + s, events.size(), LAYOUT.size()],
		)
		check(
			counts.hit + counts.anim_hit + counts.effect_hit == w.hits,
			"seed %d: hit events don't re-sum" % [SEED + s],
		)
		check(
			counts.hit + counts.anim_hit == w.actor_hits,
			"seed %d: actor_hits don't re-sum" % [SEED + s],
		)
		check(
			counts.whiff + counts.anim_whiff == w.misses,
			"seed %d: misses don't re-sum" % [SEED + s],
		)
		check(
			is_equal_approx(bore, w.boredom),
			"seed %d: boredom %f vs %f" % [SEED + s, bore, w.boredom],
		)
		check(is_equal_approx(top, w.peak), "seed %d: peak %f vs %f" % [SEED + s, top, w.peak])


func collector_changes_nothing() -> void:
	for s in SEEDS:
		var off_rng := RandomNumberGenerator.new()
		off_rng.seed = SEED + s
		var on_rng := RandomNumberGenerator.new()
		on_rng.seed = SEED + s
		var off: Dictionary = Walkthrough.run(LAYOUT, off_rng)
		var on: Dictionary = Walkthrough.run(
			LAYOUT,
			on_rng,
			Walkthrough.RECOVERY,
			Walkthrough.DEFAULT_CEILING,
			Walkthrough.PRIME_SCALE,
			Walkthrough.DEFAULT_TANK,
			1.0,
			[],
			[],
		)
		check(off == on, "seed %d: collector changed the night" % [SEED + s])


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)


func night_conservation() -> void:
	var layout := ["p", "g", "a", "g", "e", "a", "n", "g", "a"] # headcount 10
	var roster: Array[Dictionary] = []
	for s in [9.0, 8.0, 7.0, 6.5, 6.0, 5.5, 5.0, 4.5, 4.0, 3.5, 3.0, 2.0]:
		roster.append({ skill = s })
	for s in SEEDS:
		var board: Dictionary = Casting.resolve(layout, roster, [1, 4, 10], Casting.REASSIGN)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + s
		var group_records: Array = []
		var r: Dictionary = Night.run(
			board.layout,
			Night.LOOSE_INTERVAL,
			rng,
			90,
			Walkthrough.PRIME_SCALE,
			"",
			0.0,
			[],
			group_records,
		)
		var t: Dictionary = Records.attribute(group_records, board, roster)
		var screams := 0
		var whiffs := 0
		for a in t.actors.values():
			screams += a.screams
			whiffs += a.whiffs
		check(
			group_records.size() == r.groups,
			"seed %d: %d records for %d groups" % [SEED + s, group_records.size(), r.groups],
		)
		check(
			screams + t.machine.hits == roundi(r.real_hit_average * r.groups),
			"seed %d: actor hits leak" % [SEED + s],
		)
		check(
			whiffs + t.machine.whiffs == roundi(r.misses * r.groups),
			"seed %d: whiffs leak" % [SEED + s],
		)
		check(
			screams + t.machine.hits + t.effects.hits == roundi(r.hit_average * r.groups),
			"seed %d: total hits leak" % [SEED + s],
		)


func season_collector_changes_nothing() -> void:
	var alloc := { build = 11_000.0, quality = 6_000.0, depth = 5_000.0, marketing = 4_000.0 }
	for s in 5:
		var off: Array[Dictionary] = Allocation.run_season(alloc, SEED + s)
		var records := { }
		var on: Array[Dictionary] = Allocation.run_season(
			alloc,
			SEED + s,
			Casting.REASSIGN,
			true,
			records,
		)
		check(off == on, "seed %d: records collector changed the season" % [SEED + s])
		check(not records.nights.is_empty(), "seed %d: no nights sampled" % [SEED + s])
		check(not records.careers.is_empty(), "seed %d: no careers accumulated" % [SEED + s])


func quiet_night_no_card() -> void:
	var built := ["a", "g", "a", "g", "a"]
	var quiet := {
		night = 8,
		type = "skeptic",
		satisfaction = 60.0,
		reputation = 60.0,
		tonight = built,
		events = [
			{ room = 0, kind = "hit", reaction = 60.0, bore = 0.0 },
			{ room = 1, kind = "corridor", reaction = 0.0, bore = 0.0 },
			{ room = 2, kind = "hit", reaction = 55.0, bore = 0.0 },
			{ room = 3, kind = "corridor", reaction = 0.0, bore = 0.0 },
			{ room = 4, kind = "hit", reaction = 50.0, bore = 0.0 },
		],
	}
	check(not Records.salient(quiet, Records.claims(quiet, built)), "quiet night made a card")

	var deviant: Dictionary = quiet.duplicate(true)
	deviant.satisfaction = 85.0
	check(Records.salient(deviant, Records.claims(deviant, built)), "deviation didn't fire")

	var fizzled: Dictionary = quiet.duplicate(true)
	fizzled.events[4] = { room = 4, kind = "whiff", reaction = 0.0, bore = 0.0 }
	check(Records.salient(fizzled, Records.claims(fizzled, built)), "fizzle didn't fire")

	var dark: Dictionary = quiet.duplicate(true)
	dark.events[2] = { room = 2, kind = "corridor", reaction = 0.0, bore = 0.0 }
	check(Records.salient(dark, Records.claims(dark, built)), "dead room didn't fire")


func claims_are_honest() -> void:
	var alloc := { build = 11_000.0, quality = 6_000.0, depth = 5_000.0, marketing = 4_000.0 }
	for s in 5:
		var records := { }
		Allocation.run_season(alloc, SEED + s, Casting.REASSIGN, true, records)
		for rec in records.nights:
			for c in Records.claims(rec, records.built):
				if c.source == -1:
					continue
				var where := "seed %d night %d %s" % [SEED + s, rec.night, c.kind]
				if c.source < 0 or c.source >= rec.events.size():
					failed += 1
					print("FAIL: %s: source %d out of range" % [where, c.source])
					continue
				var e: Dictionary = rec.events[c.source]
				check(
					e.room == c.room,
					"%s: claim room %d, event room %d" % [where, c.room, e.room],
				)
				match c.kind:
					"dead_room":
						check(
							e.kind == "corridor" and records.built[c.room] != Rooms.CORRIDOR,
							"%s: not a built room walked as corridor" % where,
						)
					"bore":
						check(
							e.kind == "corridor" and e.bore > 0.0,
							"%s: not a boring corridor" % where,
						)
					"whiff":
						check(e.kind in ["whiff", "anim_whiff"], "%s: not a whiff event" % where)
					"fizzled_ending":
						check(e.kind in ["whiff", "anim_whiff"], "%s: not a whiff event" % where)
						for j in range(c.source + 1, rec.events.size()):
							check(
								rec.events[j].kind == "corridor",
								"%s: scare after the finale" % where,
							)
					"best_moment":
						check(
							e.kind in ["hit", "anim_hit", "effect_hit"],
							"%s: not a hit event" % where,
						)
						for other in rec.events:
							check(other.reaction <= e.reaction, "%s: better moment exists" % where)
					_:
						failed += 1
						print("FAIL: %s: unknown claim kind" % where)


func full_season_conservation() -> void:
	for alloc in [BUILD_HEAVY, CAST_HEAVY]:
		for s in 5:
			var off: Array[Dictionary] = Allocation.run_season(alloc, SEED + s)
			var records := { }
			var on: Array[Dictionary] = Allocation.run_season(
				alloc,
				SEED + s,
				Casting.REASSIGN,
				true,
				records,
			)
			check(off == on, "seed %d: collector changed gate finals" % [SEED + s])
			for row in records.box:
				var where := "seed %d night %d" % [SEED + s, row.night]
				check(
					row.screams + row.machine_hits == row.actor_hits,
					"%s: actor hits leak" % where,
				)
				check(row.whiffs + row.machine_whiffs == row.misses, "%s: whiffs leak" % where)
				check(
					row.screams + row.machine_hits + row.effect_hits == row.hits,
					"%s: total hits leak" % where,
				)
