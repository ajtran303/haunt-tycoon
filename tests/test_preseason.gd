extends SceneTree

const Night = preload("res://sim/night.gd")
const Allocation = preload("res://sim/allocation.gd")
const Preseason = preload("res://sim/preseason.gd")

const SIX_SCARE := ["a", "g", "a", "g", "a", "a", "g", "a", "g", "a"]
const SEED := 12345

var failed := 0


func _initialize() -> void:
	rungs_certify_packed()
	dense_build_clips()
	print("PASS: preseason invariants hold" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


func rungs_certify_packed() -> void:
	print("layout | cap | floor")
	for rung in Allocation.BUILD_LADDER:
		var layout: Array = rung[1]
		var floor_interval: float = Preseason.dispatch_floor(layout)
		print("%s | %d | %.0fs" % ["".join(layout), Preseason.marshal_cap(layout), floor_interval])
		check(
			floor_interval <= Night.PACKED_INTERVAL,
			"rung %s floors at %.1fs, above packed" % ["".join(layout), floor_interval],
		)


func dense_build_clips() -> void:
	var floor_interval: float = Preseason.dispatch_floor(SIX_SCARE)
	check(
		floor_interval > Night.PACKED_INTERVAL,
		"6-scare build certifies packed (floor %.1fs); cap should bind" % floor_interval,
	)

	var packed_rng := RandomNumberGenerator.new()
	packed_rng.seed = SEED
	var floored_rng := RandomNumberGenerator.new()
	floored_rng.seed = SEED
	var packed: Dictionary = Night.run(
		SIX_SCARE,
		Night.PACKED_INTERVAL,
		packed_rng,
		Night.NIGHT_CAPACITY,
	)
	var floored: Dictionary = Night.run(
		SIX_SCARE,
		floor_interval,
		floored_rng,
		Night.NIGHT_CAPACITY,
	)
	check(floored.groups < packed.groups, "cap admitted as many groups as packed")
	check(floored.tickets < packed.tickets, "cap didn't clip ticket revenue")


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)
