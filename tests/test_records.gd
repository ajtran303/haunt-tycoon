extends SceneTree

const Walkthrough = preload("res://sim/walkthrough.gd")
const Rooms = preload("res://sim/rooms.gd")

const LAYOUT := ["a", "g", "e", "g", "g", "p", "n", "g", "g", "a"]
const SEED := 12345
const SEEDS := 20

var failed := 0


func _initialize() -> void:
	events_resum()
	collector_changes_nothing()
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
