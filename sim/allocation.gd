const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")

const ROOMS := 10
const SCARE_MARGINAL := 1_500.0 # BUILD_COST.a - BUILD_COST.g
const BASE_BUILD := 5_000.0 # ten corridors

const MAX_SCARES := 6

const DOLLARS_PER_CEILING_POINT := 1_500.0
const MAX_CEILING_BONUS := 10.0

const CALLOUT_CHANCE := 0.08 # per scare room per night
const SPARE_COST := 5_000.0 # season retainer, ~half a full wage run

const DOLLARS_PER_REP := 400.0
const MAX_STARTING_REP := 78.0 # stays under REP_FULL_REACH (82)

const CASH_OUT_DAY := 25 # sim's known-good packing window is interior, ~day 24-27

const BUILD_LADDER := [
	[9_500.0, ["a", "g", "g", "a", "g", "g", "g", "g", "g", "a"]], # 3 scares
	[11_000.0, ["a", "g", "g", "a", "g", "g", "a", "g", "g", "a"]], # 4 scares
	[23_000.0, ["a", "g", "n", "g", "a", "g", "a", "g", "g", "a"]], # + anim mid
	[34_500.0, ["a", "g", "n", "g", "a", "n", "a", "g", "g", "a"]], # + second anim
]


static func opening_cash(alloc: Dictionary) -> float:
	return Night.STARTING_CASH \
		- Night.build_cost_for(layout_for(alloc.build)) \
		- alloc.quality \
		- spares_for(alloc.depth) * SPARE_COST \
		- alloc.marketing


static func run_season(alloc: Dictionary, seed_val: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var callout_rng := RandomNumberGenerator.new()
	callout_rng.seed = seed_val + 100_000

	var layout := layout_for(alloc.build)
	var bonus := ceiling_bonus_for(alloc.quality)
	var spares := spares_for(alloc.depth)
	var town := Town.new(starting_rep_for(alloc.marketing))

	var cash: float = Night.STARTING_CASH \
			- Night.build_cost_for(layout) \
			- alloc.quality \
			- spares * SPARE_COST \
			- alloc.marketing

	var trajectory: Array[float] = []
	for night in Night.SEASON_NIGHTS:
		var tonight := with_callouts(layout, spares, callout_rng)
		var interval := (
			Night.PACKED_INTERVAL if night + 1 >= CASH_OUT_DAY else Night.LOOSE_INTERVAL
		)

		var r: Dictionary = Night.run(
			tonight,
			interval,
			rng,
			town.demand(),
			Walkthrough.PRIME_SCALE,
			"",
			effective_bonus(bonus, interval),
		)
		cash += r.profit
		town.record_night(r.satisfaction)
		trajectory.append(cash)
		if cash < Night.LOAN_LIMIT:
			while trajectory.size() < Night.SEASON_NIGHTS:
				trajectory.append(cash)
			break
	return trajectory


static func layout_for(build_budget: float) -> Array:
	var best: Array = Layouts.spread(0, ROOMS)
	for rung in BUILD_LADDER:
		if rung[0] <= build_budget:
			best = rung[1]
	return best.duplicate()


static func ceiling_bonus_for(quality: float) -> float:
	return minf(quality / DOLLARS_PER_CEILING_POINT, MAX_CEILING_BONUS)


static func spares_for(depth: float) -> int:
	return int(depth / SPARE_COST)


static func starting_rep_for(marketing: float) -> float:
	return minf(Town.STARTING_REP + marketing / DOLLARS_PER_REP, MAX_STARTING_REP)


static func with_callouts(layout: Array, spares: int, rng: RandomNumberGenerator) -> Array:
	var tonight := layout.duplicate()
	var available := spares
	for i in tonight.size():
		if tonight[i] == Rooms.SCARE and rng.randf() < CALLOUT_CHANCE:
			if available > 0:
				available -= 1
			else:
				tonight[i] = Rooms.CORRIDOR
	return tonight


static func effective_bonus(bonus: float, interval: float) -> float:
	return bonus * clampf(
		(interval - Night.PACKED_INTERVAL) / (Night.LOOSE_INTERVAL - Night.PACKED_INTERVAL),
		0.0,
		1.0,
	)
