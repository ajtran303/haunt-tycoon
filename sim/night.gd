const Walkthrough = preload("res://sim/walkthrough.gd")
const Visitors = preload("res://sim/visitors.gd")
const Rooms = preload("res://sim/rooms.gd")

const SEASON_NIGHTS := 31
const NIGHT_SECONDS := 18_000.0 # 5 hours
const DEMAND := 900
const GROUP_SIZE := 9
const SECONDS_PER_ROOM := 60

const STARTING_CASH := 45_000.0
const LOAN_LIMIT := -12_500.0

const TICKET_PRICE := 25.0

const ACTORS_PER_SCARE := 2 # rotation: one on, one resetting
const ACTORS_PER_SPECIALIST := 4 # one costumer or one makeup artist covers this many actors
const SUPPORT_STAFF := 4 # queue, security, floaters
const STAFF_WAGE := 200.0
const ACTOR_WAGE := 350.0

const NIGHTLY_OVERHEAD := 4_000.0 # rent, insurance, utilities, permits
const MARKETING_PER_VISITOR := 2.5 # the industry's $2-3/head acquisition cost

const BUILD_COST := {
	"g": 500.0, # bare corridor: walls, theming, lighting
	"a": 2_000.0, # scare set: props, staging, actor blind
	"p": 3_000.0, # two-actor scene: bigger set, cue rigging
	"n": 12_000.0, # the machine itself, install, air lines
	"e": 1_500.0, # fog rig or air cannon, wiring
}

const UPKEEP := {
	"g": 50.0, # relamp, repaint scuffs
	"a": 200.0, # props, blood, costume wear: staffed rooms churn nightly
	"p": 300.0,
	"n": 600.0, # maintenance and air, but the machine needs no costumer
	"e": 150.0, # fog fluid, per the research ~$50-150/night is realistic
}

const GIFT_PER_ACTOR_HIT := 4.0
const CONCESSION_PER_MIN := 0.10 # not used yet

const SAT_RAW_MIN := 22.0
const SAT_RAW_MAX := 95.0

const REP_FLOOR := 50.0 # below this, word of mouth turns against you
const REP_FULL_REACH := 82.0 # reputation that reaches the whole pool
const MIN_REACH := 0.025 # the trickle: floor of the curve
const REP_DRIFT := 0.15 # how fast word of mouth moves: ~a week's memory

const REP_DEAD := 30.0 # town fully writes you off
const CURIOSITY_REACH := 0.08 # the rubbernecker crowd that still shows up at the floor

const PEAK_WEIGHT := 0.65 # how much the best moment counts vs the ending

const MIN_SEPARATION := 2.0 # rooms between groups
const PACKED_INTERVAL := MIN_SEPARATION * SECONDS_PER_ROOM # 120s: the dispatch floor
const LOOSE_INTERVAL := 300.0 # actors fully reset

const NIGHT_CAPACITY := int(NIGHT_SECONDS / PACKED_INTERVAL) * GROUP_SIZE # 1350 visitors

const TOWN_POOL := 1350


static func run(
	layout: Array,
	dispatch_interval: float,
	rng: RandomNumberGenerator,
	demand: int = DEMAND,
	prime_scale: float = Walkthrough.PRIME_SCALE,
	forced_type: String = "",
) -> Dictionary:
	var capacity := int(NIGHT_SECONDS / dispatch_interval)
	var groups := mini(capacity, (demand / GROUP_SIZE))
	var ceiling := actor_ceiling_for(dispatch_interval)
	var total_hits := 0
	var total_actor_hits := 0
	var total_sat := 0.0
	var total_misses := 0
	var total_boredom := 0.0
	var total_peak := 0.0
	var total_final := 0.0

	for i in groups:
		var type := forced_type if forced_type != "" else draw_type(rng)
		var v: Dictionary = Visitors.TYPES[type]
		var w: Dictionary = Walkthrough.run(
			layout,
			rng,
			Walkthrough.RECOVERY,
			ceiling,
			prime_scale,
			v.tank,
			v.depletion,
		)
		total_hits += w.hits
		total_actor_hits += w.actor_hits
		total_sat += satisfaction(w, v.tank)
		total_misses += w.misses
		total_boredom += w.boredom
		total_peak += w.peak
		total_final += w.final_reaction

	var tickets := groups * GROUP_SIZE * TICKET_PRICE
	var gift := total_actor_hits * GROUP_SIZE * GIFT_PER_ACTOR_HIT
	var wages := wages_for(layout)
	var overhead := NIGHTLY_OVERHEAD + upkeep_for(layout)
	var marketing := groups * GROUP_SIZE * MARKETING_PER_VISITOR

	return {
		"groups": groups,
		"hit_average": float(total_hits) / groups,
		"real_hit_average": float(total_actor_hits) / groups,
		"satisfaction": total_sat / groups,
		"misses": float(total_misses) / groups,
		"boredom": total_boredom / groups,
		"peak": total_peak / groups,
		"final_reaction": total_final / groups,
		"tickets": tickets,
		"gift": gift,
		"costs": wages + overhead + marketing,
		"profit": tickets + gift - wages - overhead - marketing,
	}


# 300s apart = actors fully reset. 120s = rushed.
static func actor_ceiling_for(dispatch_interval: float) -> float:
	return clampf(
		45.0 + 40.0 * (dispatch_interval - PACKED_INTERVAL) / (LOOSE_INTERVAL - PACKED_INTERVAL),
		45.0,
		85.0,
	)


static func concurrent_groups(rooms: int, dispatch_interval: float) -> float:
	return (rooms * SECONDS_PER_ROOM) / dispatch_interval


static func satisfaction(w: Dictionary, tank: float = 100.0) -> float:
	if w.hits == 0:
		return 0.0
	var raw: float = PEAK_WEIGHT * w.peak + (1.0 - PEAK_WEIGHT) * w.final_reaction
	raw *= 100.0 / tank
	raw -= w.boredom
	var t := (raw - SAT_RAW_MIN) / (SAT_RAW_MAX - SAT_RAW_MIN)
	return clampf(t * 100.0, 0.0, 100.0)


static func next_reputation(rep: float, sat: float) -> float:
	return rep + (sat - rep) * REP_DRIFT


static func demand_for(rep: float) -> int:
	var reach: float
	if rep >= REP_FLOOR:
		var t := clampf((rep - REP_FLOOR) / (REP_FULL_REACH - REP_FLOOR), 0.0, 1.0)
		reach = lerpf(CURIOSITY_REACH, 1.0, t)
	else:
		var t := clampf((rep - REP_DEAD) / (REP_FLOOR - REP_DEAD), 0.0, 1.0)
		reach = lerpf(MIN_REACH, CURIOSITY_REACH, t)
	return int(TOWN_POOL * reach)


static func draw_type(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	var acc := 0.0
	for t in Visitors.MIX:
		acc += Visitors.MIX[t]
		if roll < acc:
			return t
	return "thrill_seeker"


static func build_cost_for(layout: Array) -> float:
	var cost := 0.0
	for room in layout:
		cost += BUILD_COST[room]
	return cost


static func upkeep_for(layout: Array) -> float:
	var cost := 0.0
	for room in layout:
		cost += UPKEEP[room]
	return cost


static func staff_for(layout: Array) -> int:
	var actors := actors_for(layout)
	return actors + specialists_for(actors) + SUPPORT_STAFF


static func wages_for(layout: Array) -> float:
	var actors := actors_for(layout)
	return actors * ACTOR_WAGE + (specialists_for(actors) + SUPPORT_STAFF) * STAFF_WAGE


static func actors_for(layout: Array) -> int:
	var actors := 0
	for room in layout:
		match room:
			Rooms.SCARE:
				actors += ACTORS_PER_SCARE
			Rooms.PAIR_SCARE:
				actors += ACTORS_PER_SCARE * 2
	return actors


static func specialists_for(actors: int) -> int:
	if actors == 0:
		return 0
	return 2 * ceili(float(actors) / ACTORS_PER_SPECIALIST) # one costume team + one makeup team
