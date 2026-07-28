const Walkthrough = preload("res://sim/walkthrough.gd")
const Visitors = preload("res://sim/visitors.gd")

const NIGHT_SECONDS := 18_000.0 # 5 hours
const DEMAND := 900
const GROUP_SIZE := 9
const SECONDS_PER_ROOM := 60

const TICKET := 25.0

const CREW_PER_SCARE := 2 # rotation: one on, one resetting
const ACTORS_PER_SPECIALIST := 4 # one costumer or one makeup artist covers this many actors
const SUPPORT_STAFF := 4 # queue, security, floaters
const SUPPORT_WAGE := 100.0
const WAGE_PER_NIGHT := 150.0

const BUILD_COST := {
	"g": 500.0, # bare corridor: walls, theming, lighting
	"a": 2_000.0, # scare set: props, staging, actor blind
	"p": 3_000.0, # two-actor scene: bigger set, cue rigging
	"n": 12_000.0, # the machine itself, install, air lines
	"e": 1_500.0, # fog rig or air cannon, wiring
}

const GIFT_PER_HIT := 5.0
const CONCESSION_PER_MIN := 0.10 # not used yet

const SAT_FLOOR := 22.0
const SAT_CEILING := 95.0

const TOWN_POOL := 900 # reachable population per night at perfect reputation
const REP_FLOOR := 50.0 # below this, only morbid curiosity shows up
const REP_FULL := 82.0 # reputation that reaches the whole pool
const MIN_REACH := 0.025 # the trickle: ~22 visitors... floor of the curve
const REP_DRIFT := 0.15 # how fast word of mouth moves: ~a week's memory

const PEAK_WEIGHT := 0.65 # how much the best moment counts vs the ending


static func run(
	layout: Array,
	interval: float,
	rng: RandomNumberGenerator,
	demand: int = DEMAND,
	prime_scale: float = Walkthrough.PRIME_SCALE,
	forced_type: String = "",
) -> Dictionary:
	var capacity := int(NIGHT_SECONDS / interval)
	var groups := mini(capacity, (demand / GROUP_SIZE))
	var ceiling := ceiling_for(interval)
	var total_hits := 0
	var total_real_hits := 0
	var total_sat := 0.0

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
		total_real_hits += w.real_hits
		total_sat += satisfaction(w, v.tank)

	var tickets := groups * GROUP_SIZE * TICKET
	var gift := total_real_hits * GROUP_SIZE * GIFT_PER_HIT
	var wages := wages_for(layout)

	return {
		"groups": groups,
		"hit_average": float(total_hits) / groups,
		"real_hit_average": float(total_real_hits) / groups,
		"satisfaction": total_sat / groups,
		"profit": tickets + gift - wages,
	}


static func staff_for(layout: Array) -> int:
	var staff := SUPPORT_STAFF
	for room in layout:
		match room:
			"a":
				staff += CREW_PER_SCARE
			"p":
				staff += CREW_PER_SCARE * 2
	return staff


# Min feasible interval = MIN_SEPARATION * SECONDS_PER_ROOM = 120s.
# 300s apart = actors fully reset. 120s = rushed.
static func ceiling_for(interval: float) -> float:
	return clampf(45.0 + 40.0 * (interval - 120.0) / 180.0, 45.0, 85.0)


static func groups_inside(rooms: int, interval: float) -> float:
	return (rooms * SECONDS_PER_ROOM) / interval


static func satisfaction(w: Dictionary, tank: float = 100.0) -> float:
	if w.hits == 0:
		return 0.0
	var raw: float = PEAK_WEIGHT * w.peak + (1.0 - PEAK_WEIGHT) * w.end
	raw *= 100.0 / tank
	raw -= w.boredom
	var t := (raw - SAT_FLOOR) / (SAT_CEILING - SAT_FLOOR)
	return clampf(t * 100.0, 0.0, 100.0)


static func next_reputation(rep: float, sat: float) -> float:
	return rep + (sat - rep) * REP_DRIFT


static func demand_for(rep: float) -> int:
	var reach := clampf((rep - REP_FLOOR) / (REP_FULL - REP_FLOOR), MIN_REACH, 1.0)
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


static func wages_for(layout: Array) -> float:
	var actors := 0
	for room in layout:
		match room:
			"a":
				actors += CREW_PER_SCARE
			"p":
				actors += CREW_PER_SCARE * 2
	var specialists := 0
	if actors > 0:
		specialists = 2 * ceili(float(actors) / ACTORS_PER_SPECIALIST) # one costume team + one makeup team
	return actors * WAGE_PER_NIGHT + (specialists + SUPPORT_STAFF) * SUPPORT_WAGE
