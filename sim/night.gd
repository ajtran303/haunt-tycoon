const Walkthrough = preload("res://sim/walkthrough.gd")
const Visitors = preload("res://sim/visitors.gd")

const NIGHT_SECONDS := 18_000.0 # 5 hours
const DEMAND := 900
const GROUP_SIZE := 9
const SECONDS_PER_ROOM := 60

const TICKET := 25.0

const CREW_PER_SCARE := 2 # rotation: one on, one resetting
const SUPPORT_STAFF := 4 # queue, security, floaters
const WAGE_PER_NIGHT := 150.0

const GIFT_PER_HIT := 5.0
const CONCESSION_PER_MIN := 0.10 # not used yet

const SAT_FLOOR := 22.0
const SAT_CEILING := 95.0

const BREAK_EVEN_SAT := 68.0
const GROWTH_PER_SAT_POINT := 0.01 # demand change per satisfaction point per night

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
	var wages := staff_for(layout) * WAGE_PER_NIGHT

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


static func next_demand(demand: int, satisfaction: float) -> int:
	return int(demand * (1.0 + (satisfaction - BREAK_EVEN_SAT) * GROWTH_PER_SAT_POINT))


static func draw_type(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	var acc := 0.0
	for t in Visitors.MIX:
		acc += Visitors.MIX[t]
		if roll < acc:
			return t
	return "thrill_seeker"
