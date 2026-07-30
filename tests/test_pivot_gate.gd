extends SceneTree

const Allocation = preload("res://sim/allocation.gd")
const Night = preload("res://sim/night.gd")

const BUILD_HEAVY := { build = 23_000.0, quality = 0.0, depth = 0.0, marketing = 1_000.0 }
const CAST_HEAVY := { build = 9_500.0, quality = 14_000.0, depth = 5_000.0, marketing = 1_000.0 }

const SEED := 12345
const SEEDS := 5
const MAX_MEAN_GAP := 1.15 # band applies to mean finals across the sweep
const MIN_CROSSING_SEEDS := 3 # the lead changes hands on most seeds

var failed := 0


func _initialize() -> void:
	var build_finals: Array[float] = []
	var cast_finals: Array[float] = []
	var crossing_seeds := 0

	print("seed  | crossings | build final | cast final | gap")
	for s in SEEDS:
		var a := cash_of(Allocation.run_season(BUILD_HEAVY, SEED + s))
		var b := cash_of(Allocation.run_season(CAST_HEAVY, SEED + s))
		var gap := maxf(a[-1], b[-1]) / minf(a[-1], b[-1])
		print("%d | %9d | $%.0f | $%.0f | %.2fx" % [SEED + s, crossings(a, b), a[-1], b[-1], gap])
		build_finals.append(a[-1])
		cast_finals.append(b[-1])
		if crossings(a, b) >= 1:
			crossing_seeds += 1
		check(
			a[-1] > Night.LOAN_LIMIT and b[-1] > Night.LOAN_LIMIT,
			"seed %d: an archetype goes bankrupt" % (SEED + s),
		)

	check(
		crossing_seeds >= MIN_CROSSING_SEEDS,
		"lead changes hands on only %d of %d seeds" % [crossing_seeds, SEEDS],
	)

	var mean_build := mean(build_finals)
	var mean_cast := mean(cast_finals)
	check(mean_build > 0.0 and mean_cast > 0.0, "an archetype ends underwater on average")
	if mean_build > 0.0 and mean_cast > 0.0:
		var gap := maxf(mean_build, mean_cast) / minf(mean_build, mean_cast)
		print("mean  |           | $%.0f | $%.0f | %.2fx" % [mean_build, mean_cast, gap])
		check(gap <= MAX_MEAN_GAP, "mean final gap %.0f%% exceeds 15%%" % ((gap - 1.0) * 100.0))

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


static func mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)


static func cash_of(records: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for r in records:
		out.append(r.cash)
	return out
