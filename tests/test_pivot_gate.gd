extends SceneTree

const Allocation = preload("res://sim/allocation.gd")

const BUILD_HEAVY := { build = 23_000.0, quality = 0.0, depth = 0.0, marketing = 0.0 }
const CAST_HEAVY := { build = 9_500.0, quality = 15_000.0, depth = 5_000.0, marketing = 0.0 }

const SEED := 12345
const SEEDS := 5
const MAX_FINAL_GAP := 1.15

var failed := 0

func _initialize() -> void:
	var a := Allocation.run_season(BUILD_HEAVY, SEED)
	var b := Allocation.run_season(CAST_HEAVY, SEED)

	check(crossings(a, b) >= 1, "lead never changes hands")
	check(a[-1] > 0.0 and b[-1] > 0.0, "an allocation ends underwater")
	if a[-1] > 0.0 and b[-1] > 0.0:
		var gap := maxf(a[-1], b[-1]) / minf(a[-1], b[-1])
		check(gap <= MAX_FINAL_GAP, "final gap %.0f%% exceeds 15%%" % ((gap - 1.0) * 100.0))

	if failed > 0:
		print_trajectories(a, b)
	sweep()
	print("PASS: pivot gate holds" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


static func crossings(a: Array[float], b: Array[float]) -> int:
	var n := 0
	var last := 0.0
	for i in a.size():
		var s := signf(a[i] - b[i])
		if s != 0.0:
			if last != 0.0 and s != last:
				n += 1
			last = s
	return n


func print_trajectories(a: Array[float], b: Array[float]) -> void:
	print("\nnight | build-heavy | cast-heavy | lead")
	for i in a.size():
		print(
			"%5d | $%.0f | $%.0f | %s"
			% [i + 1, a[i], b[i], "build" if a[i] > b[i] else ("cast" if b[i] > a[i] else "tie")]
		)


func sweep() -> void:
	print("\nseed  | crossings | build final | cast final | gap")
	for s in SEEDS:
		var a := Allocation.run_season(BUILD_HEAVY, SEED + s)
		var b := Allocation.run_season(CAST_HEAVY, SEED + s)
		var gap := maxf(a[-1], b[-1]) / minf(a[-1], b[-1])
		print("%d | %9d | $%.0f | $%.0f | %.2fx" % [SEED + s, crossings(a, b), a[-1], b[-1], gap])


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)
