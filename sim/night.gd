const Walkthrough = preload("res://sim/walkthrough.gd")

const NIGHT_SECONDS := 18_000.0 # 5 hours
const DEMAND := 900
const GROUP_SIZE := 9
const SECONDS_PER_ROOM := 60

const TICKET := 25.0
const WAGE_PER_NIGHT := 90.0
const GIFT_PER_HIT := 1.0
const CONCESSION_PER_MIN := 0.10 # not used yet

const SAT_BASE := 40.0
const SAT_PER_HIT := 12.0
const SAT_PER_MISS := SAT_PER_HIT / 2

static func run(layout: Array, interval: float, actors: int, rng, demand: int = DEMAND) -> Dictionary:
	var capacity := int(NIGHT_SECONDS / interval)
	var groups := mini(capacity, (demand / GROUP_SIZE))
	var ceiling := ceiling_for(interval)
	var total_hits := 0
	var total_sat := 0.0

	for i in groups:
		var w: Dictionary = Walkthrough.run(layout, rng, Walkthrough.RECOVERY, ceiling)
		total_hits += w.hits
		total_sat += satisfaction(w)

	var tickets := groups * GROUP_SIZE * TICKET
	var gift := total_hits * GROUP_SIZE * GIFT_PER_HIT
	var wages := actors * WAGE_PER_NIGHT

	return {
		"groups": groups,
		"hit_average": float(total_hits) / groups,
		"satisfaction": total_sat / groups,
		"profit": tickets + gift - wages,
	  }

# Min feasible interval = MIN_SEPARATION * SECONDS_PER_ROOM = 120s.
# 300s apart = actors fully reset. 120s = rushed.
static func ceiling_for(interval: float) -> float:
	return clampf(45.0 + 40.0 * (interval - 120.0) / 180.0, 45.0, 85.0)

static func groups_inside(rooms: int, interval: float) -> float:
	return (rooms * SECONDS_PER_ROOM) / interval

static func satisfaction(w: Dictionary) -> float:
	if w.hits == 0:
		return 0.0
	return (w.peak + w.end) / 2.0
