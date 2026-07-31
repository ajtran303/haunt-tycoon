extends SceneTree

const Allocation = preload("res://sim/allocation.gd")
const Calendar = preload("res://sim/calendar.gd")

const Gate = preload("res://tests/test_pivot_gate.gd")

const BALANCED := { build = 11_000.0, quality = 6_000.0, depth = 5_000.0, marketing = 4_000.0 }

const BAND_LO := 0.60
const BAND_HI := 0.75
const RAIL_LO := 0.55
const RAIL_HI := 0.85

const SEED := 12345
const SEEDS := 5

var failed := 0

func _initialize() -> void:
	check_share("balanced", BALANCED, BAND_LO, BAND_HI)
	check_share("build heavy", Gate.BUILD_HEAVY, RAIL_LO, RAIL_HI)
	check_share("cast heavy", Gate.CAST_HEAVY, RAIL_LO, RAIL_HI)
	print("PASS: season shape holds" if failed == 0 else "FAIL: %d broken" % failed)		
	quit(1 if failed > 0 else 0)

func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)

func check_share(name: String, archetype: Dictionary, low: float, high: float) -> void:
	print(name)
	for s in SEEDS:
		var records := Allocation.run_season(archetype, SEED + s)
		var counted := 0.0
		var total := 0.0
		for i in records.size():
			total += records[i].revenue
			if Calendar.is_counted(i + 1):
				counted += records[i].revenue
		var share := counted / total
		check(
			share >= low and share <= high,
			"seed %d: weekend share %.1f%%" % [SEED + s, share * 100.0],
		)
