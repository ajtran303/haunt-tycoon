extends SceneTree
# Balance invariants. Run after every constant change:
#   godot --headless --path . -s tests/test_invariants.gd
# Thresholds calibrated at 4a80764 (2026-07-28).
# Tighten deliberately; never loosen to make a red run green.

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Town = preload("res://sim/town.gd")
const Visitors = preload("res://sim/visitors.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")

const SEEDS := 5

const TRAP_CEILING := -100_000.0 # front_loaded must lose at least this much
const EARLIEST_BREAK_EVEN := 7 # currently 9-14 after the 2026-07-28 repricing
const CASH_OUT_WINDOW := [10, 29] # peak must be interior; currently day 24-27
# Dollar cap, not %: repricing (gift 5→4, overhead 3.5k→4k, wage 300→350)
# inflated the % gain 38→53 while the absolute bonus stayed ~$85k.
const MAX_CASH_OUT_BONUS := 100_000.0 # pair_bank $85k at calibration
const MIN_TOP_BONUS := 40_000.0 # below this, the cash-out mechanic is dead
const MIN_SPREAD := 1.30 # best/worst viable; currently 1.84, was 1.34 pre-repricing
const AUDIENCE_CAP := 75.0 # every layout leaves one type below this; pair_bank sits at 74

const TROUGH_MARGIN := 2_500.0 # viable presets must clear the loan line by this much

# Density is expression, not strategy: with no occupancy cap, payroll must be
# what stops wall-to-wall scares. No dense build may lead the field past the band.
const DENSE_BUILDS := {
	six_scare = ["a", "g", "a", "g", "a", "a", "g", "a", "g", "a"],
	wall_to_wall = ["a", "a", "a", "a", "a", "a", "a", "a", "a", "a"],
}
const DENSE_LEAD := 1.15

var failed := 0


func _initialize() -> void:
	var viable: Array = Layouts.PRESETS.keys().filter(
		func(p):
			return p != "front_loaded",
	)

	check(
		mean_total(Layouts.PRESETS["front_loaded"], 31) < TRAP_CEILING,
		"trap layout no longer loses money",
	)

	var best_means := { }
	var max_bonus := 0.0
	for p in viable:
		var layout: Array = Layouts.PRESETS[p]

		var be := break_even_night(layout)
		check(
			be >= EARLIEST_BREAK_EVEN and be <= Night.SEASON_NIGHTS,
			"%s breaks even night %d" % [p, be],
		)

		var never_pack := mean_total(layout, Night.SEASON_NIGHTS + 1)
		var best := never_pack
		var best_day := Night.SEASON_NIGHTS + 1
		for day in range(1, Night.SEASON_NIGHTS + 1):
			var m := mean_total(layout, day)
			if m > best:
				best = m
				best_day = day
		best_means[p] = best
		check(
			best_day >= CASH_OUT_WINDOW[0] and best_day <= CASH_OUT_WINDOW[1],
			"%s cash-out peak at day %d, not interior" % [p, best_day],
		)
		var bonus := best - never_pack
		max_bonus = maxf(max_bonus, bonus)
		check(bonus <= MAX_CASH_OUT_BONUS, "%s cash-out bonus $%.0f" % [p, bonus])

		var worst_type_sat := 100.0
		for t in Visitors.TYPES:
			worst_type_sat = minf(worst_type_sat, audience_sat(layout, t))
		check(
			worst_type_sat <= AUDIENCE_CAP,
			"%s delights every audience type (worst %.1f)" % [p, worst_type_sat],
		)

		var trough := worst_trough(layout)
		check(
			trough > Night.LOAN_LIMIT + TROUGH_MARGIN,
			"%s cash trough $%.0f grazes the loan line" % [p, trough],
		)

	# Loss floor: a half-full house must lose money.
	var floor_rng := RandomNumberGenerator.new()
	floor_rng.seed = 4242
	var half_house: Dictionary = Night.run(
		Layouts.PRESETS["handpicked"],
		Night.LOOSE_INTERVAL,
		floor_rng,
		30 * Night.GROUP_SIZE,
	)
	check(half_house.profit < 0.0, "50%% house still profits ($%.0f)" % half_house.profit)

	var spread: float = best_means.values().max() / best_means.values().min()
	check(spread >= MIN_SPREAD, "viable spread %.2fx: field is flattening" % spread)

	var best_viable: float = best_means.values().max()
	for name in DENSE_BUILDS:
		var dense_best := mean_total(DENSE_BUILDS[name], Night.SEASON_NIGHTS + 1)
		for day in range(1, Night.SEASON_NIGHTS + 1, 3):
			dense_best = maxf(dense_best, mean_total(DENSE_BUILDS[name], day))
		check(
			dense_best <= best_viable * DENSE_LEAD,
			"%s leads the field: $%.0f vs best viable $%.0f" % [name, dense_best, best_viable],
		)

	check(
		max_bonus >= MIN_TOP_BONUS,
		"best cash-out bonus only $%.0f: packing no longer matters" % max_bonus,
	)

	check(
		worst_trough(Layouts.PRESETS["front_loaded"]) < Night.LOAN_LIMIT,
		"trap layout survives the loan line",
	)

	print("PASS: all invariants hold" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)


func season_total(layout: Array, cash_out_day: int, seed_offset: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + seed_offset
	var total := -Night.build_cost_for(layout)
	var town := Town.new()
	for night in Night.SEASON_NIGHTS:
		var interval: float = (
			Night.PACKED_INTERVAL if night + 1 >= cash_out_day else Night.LOOSE_INTERVAL
		)
		var r: Dictionary = Night.run(layout, interval, rng, town.demand())
		total += r.profit
		town.record_night(r.satisfaction)
	return total


func mean_total(layout: Array, cash_out_day: int) -> float:
	var sum := 0.0
	for s in SEEDS:
		sum += season_total(layout, cash_out_day, s)
	return sum / SEEDS


# First night cumulative profit (incl. build cost) turns non-negative, never packing.
func break_even_night(layout: Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var total := -Night.build_cost_for(layout)
	var town := Town.new()
	for night in Night.SEASON_NIGHTS:
		var r: Dictionary = Night.run(layout, Night.LOOSE_INTERVAL, rng, town.demand())
		total += r.profit
		town.record_night(r.satisfaction)
		if total >= 0.0:
			return night + 1
	return 99


func audience_sat(layout: Array, type: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var total := 0.0
	for i in 10:
		var r: Dictionary = Night.run(
			layout,
			Night.LOOSE_INTERVAL,
			rng,
			900,
			Walkthrough.PRIME_SCALE,
			type,
		)
		total += r.satisfaction
	return total / 10.0


func worst_trough(layout: Array) -> float:
	var worst := INF
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345 + s
		var cash: float = Night.STARTING_CASH - Night.build_cost_for(layout)
		var town := Town.new()
		for night in Night.SEASON_NIGHTS:
			var r: Dictionary = Night.run(layout, Night.LOOSE_INTERVAL, rng, town.demand())
			cash += r.profit
			town.record_night(r.satisfaction)
			worst = minf(worst, cash)
	return worst
