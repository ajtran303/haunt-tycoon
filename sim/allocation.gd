const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")
const Calendar = preload("res://sim/calendar.gd")
const Roster = preload("res://sim/roster.gd")
const Casting = preload("res://sim/casting.gd")
const Records = preload("res://sim/records.gd")

const ROOMS := 10
const SCARE_MARGINAL := 1_500.0 # BUILD_COST.a - BUILD_COST.g
const BASE_BUILD := 5_000.0 # ten corridors

const DOLLARS_PER_CEILING_POINT := 1_500.0
const MAX_CEILING_BONUS := 10.0

const SPARE_COST := 5_000.0 # season retainer, ~half a full wage run
const ON_CALL_WAGE := 175.0

const DOLLARS_PER_REP := 400.0
const MAX_STARTING_REP := 78.0 # stays under REP_FULL_REACH (82)
const HIRE_TIER_DOLLARS := DOLLARS_PER_CEILING_POINT * MAX_CEILING_BONUS # 15_000

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


static func run_season(
	alloc: Dictionary,
	seed_val: int,
	policy: int = Casting.REASSIGN,
	callouts: bool = true,
	records: Variant = null,
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var callout_rng := RandomNumberGenerator.new()
	callout_rng.seed = seed_val + 100_000
	var roster_rng := RandomNumberGenerator.new()
	roster_rng.seed = seed_val + 300_000

	var layout := layout_for(alloc.build)
	var roster := roster_for(alloc, roster_rng)

	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = seed_val + 400_000
	if records != null:
		records.built = layout
		records.roster = roster
		records.careers = { }
		records.nights = []

	var headcount := Night.actors_for(layout)
	var town := Town.new(starting_rep_for(alloc.marketing))

	var cash: float = Night.STARTING_CASH \
			- Night.build_cost_for(layout) \
			- alloc.quality \
			- alloc.marketing

	var trajectory: Array[Dictionary] = []
	var weather := Calendar.roll_season(seed_val)

	for night in Night.SEASON_NIGHTS:
		var absent: Array = Roster.roll_callouts(roster, callout_rng) if callouts else []
		var board: Dictionary = Casting.resolve(layout, roster, absent, policy)
		var tonight: Array = board.layout

		var demand := int(
			town.demand() * Calendar.weight_for(night + 1) * Calendar.WEATHER[weather[night]].mult
		)

		var is_dark_night := is_dark(tonight, demand, night + 1)

		var revenue := 0.0
		if is_dark_night:
			cash -= Night.NIGHTLY_OVERHEAD
		else:
			for i in absent:
				roster[i].observed_callouts += 1
			var loose_cap := int(Night.NIGHT_SECONDS / Night.LOOSE_INTERVAL) * Night.GROUP_SIZE
			var interval := Night.PACKED_INTERVAL if demand > loose_cap else Night.LOOSE_INTERVAL
			var bonus_row: Array = []
			for c in board.ceilings:
				bonus_row.append(effective_bonus(c, interval))
			var group_records: Variant = [] if records != null else null
			var r: Dictionary = Night.run(
				tonight,
				interval,
				rng,
				demand,
				Walkthrough.PRIME_SCALE,
				"",
				0.0,
				bonus_row,
				group_records,
			)
			cash += r.profit - (
				roster_wages(roster, headcount, absent, policy) - Night.wages_for(tonight)
			)
			town.record_night(r.satisfaction)
			revenue = r.tickets + r.gift
			if records != null:
				Records.digest(records, group_records, board, roster, night + 1, sample_rng)

		trajectory.append({ cash = cash, revenue = revenue })
		if cash < Night.LOAN_LIMIT:
			while trajectory.size() < Night.SEASON_NIGHTS:
				trajectory.append({ cash = cash, revenue = 0.0 })
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


static func effective_bonus(bonus: float, interval: float) -> float:
	var t := clampf(
		(interval - Night.PACKED_INTERVAL) / (Night.LOOSE_INTERVAL - Night.PACKED_INTERVAL),
		0.0,
		1.0,
	)
	return bonus * lerpf(0.7, 1.0, t)


static func is_dark(tonight: Array, demand: int, night: int) -> bool: # night is 1-based
	var must_open := Calendar.weekday(night) in [0, 5, 6] \
			or night >= Calendar.HALLOWEEN_WEEK_START
	var marginal := Night.wages_for(tonight) + Night.upkeep_for(tonight)
	return not must_open \
			and demand * (Night.TICKET_PRICE - Night.MARKETING_PER_VISITOR) < marginal


static func roster_for(alloc: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var headcount := Night.actors_for(layout_for(alloc.build))
	var bench := spares_for(alloc.depth)
	var tier := minf(alloc.quality / HIRE_TIER_DOLLARS, 1.0)
	return Roster.auto_hire(Roster.pool(rng, headcount + bench, tier), headcount, bench)


static func roster_wages(
	roster: Array[Dictionary],
	headcount: int,
	absent: Array,
	policy: int,
) -> float:
	var absent_performers := 0
	var absent_bench := 0
	for i in absent:
		if i < headcount:
			absent_performers += 1
		else:
			absent_bench += 1
	var present_bench := roster.size() - headcount - absent_bench
	var bench_used := mini(absent_performers, present_bench) if policy == Casting.REASSIGN else 0
	return (headcount - absent_performers + bench_used) * Night.ACTOR_WAGE \
			+ (present_bench - bench_used) * ON_CALL_WAGE \
			+ (Night.specialists_for(headcount) + Night.SUPPORT_STAFF) * Night.STAFF_WAGE
