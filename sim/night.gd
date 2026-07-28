const Walkthrough = preload("res://sim/walkthrough.gd")

const NIGHT_SECONDS := 18_000.0 # 5 hours
const DEMAND := 900
const GROUP_SIZE := 9
const SECONDS_PER_ROOM := 60

const TICKET := 25.0

const CREW_PER_SCARE := 2 # rotation: one on, one resetting
const SUPPORT_STAFF := 4  # queue, security, floaters
const WAGE_PER_NIGHT := 150.0

const GIFT_PER_HIT := 5.0
const CONCESSION_PER_MIN := 0.10 # not used yet

const SAT_FLOOR := 22.0
const SAT_CEILING := 85.0

const BREAK_EVEN_SAT := 70.0
const GROWTH_PER_SAT_POINT := 0.01 # demand change per satisfaction point per night

static func run(layout: Array, interval: float, rng, demand: int = DEMAND) -> Dictionary:
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
	var wages := staff_for(layout) * WAGE_PER_NIGHT

	return {
		"groups": groups,
		"hit_average": float(total_hits) / groups,
		"satisfaction": total_sat / groups,
		"profit": tickets + gift - wages,
	  }

static func staff_for(layout: Array) -> int:
	return layout.count(true) * CREW_PER_SCARE + SUPPORT_STAFF

# Min feasible interval = MIN_SEPARATION * SECONDS_PER_ROOM = 120s.
# 300s apart = actors fully reset. 120s = rushed.
static func ceiling_for(interval: float) -> float:
	return clampf(45.0 + 40.0 * (interval - 120.0) / 180.0, 45.0, 85.0)

static func groups_inside(rooms: int, interval: float) -> float:
	return (rooms * SECONDS_PER_ROOM) / interval

static func satisfaction(w: Dictionary) -> float:
	if w.hits == 0:
		return 0.0
	var raw := float(w.peak + w.end) / 2.0
	var t := (raw - SAT_FLOOR) / (SAT_CEILING - SAT_FLOOR)
	return clampf(t * 100.0, 0.0, 100.0)

static func next_demand(demand: int, satisfaction: float) -> int:
	return int(demand * (1.0 + (satisfaction - BREAK_EVEN_SAT) * GROWTH_PER_SAT_POINT))
