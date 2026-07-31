const Night = preload("res://sim/night.gd")


const BASE_OCCUPANCY := 65
const EGRESS_COST := { "g": 0, "a": 4, "p": 6, "n": 1, "e": 1 } # blinds and props block egress


static func marshal_cap(layout: Array) -> int:
	var cap := BASE_OCCUPANCY
	for room in layout:
		cap -= EGRESS_COST[room]
	return cap


static func dispatch_floor(layout: Array) -> float:
	return layout.size() * Night.SECONDS_PER_ROOM * Night.GROUP_SIZE / float(marshal_cap(layout))
