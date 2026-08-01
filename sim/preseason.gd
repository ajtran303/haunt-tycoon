const Night = preload("res://sim/night.gd")

const BASE_OCCUPANCY := 65
const EGRESS_COST := { "g": 0, "a": 4, "p": 6, "n": 1, "e": 1 } # blinds and props block egress

const PERMIT_FEE := 1_000.0
const REHEARSAL_NIGHTS := 7
const PRESALE_DISCOUNT := 0.2
const PRESALE_PUSH_SHARE := 0.5 # marketing split: rest is awareness
const PRESALE_PUSH_PER_TICKET := 15.0 # push dollars to presell one ticket

const PREVIEW_WEIGHT := 0.5 # how much the blurb moves opening belief
const PREVIEW_DEMAND := 90 # press and comps: ten groups

const SEASON_GOALS := [
	  { name = "loan paid", cash = 0.0 },
	  { name = "solid season", cash = 300_000.0 },
	  { name = "local legend", cash = 330_000.0 },
]

static func marshal_cap(layout: Array) -> int:
	var cap := BASE_OCCUPANCY
	for room in layout:
		cap -= EGRESS_COST[room]
	return cap


static func dispatch_floor(layout: Array) -> float:
	return layout.size() * Night.SECONDS_PER_ROOM * Night.GROUP_SIZE / float(marshal_cap(layout))


static func run_phases(
	alloc: Dictionary,
	layout: Array,
	roster_count: int,
	preview_played := true,
	discount := PRESALE_DISCOUNT,
) -> Dictionary:
	var push: float = alloc.marketing * PRESALE_PUSH_SHARE
	var presold := int(push / PRESALE_PUSH_PER_TICKET)
	var ledger: Array[Dictionary] = []
	var cash := Night.STARTING_CASH
	cash = post(ledger, "build", -Night.build_cost_for(layout), cash)
	cash = post(ledger, "marshal permit", -PERMIT_FEE, cash)
	cash = post(ledger, "casting spend", -alloc.quality, cash)
	cash = post(ledger, "marketing", -alloc.marketing, cash)
	cash = post(ledger, "presale cash", presold * Night.TICKET_PRICE * (1.0 - discount), cash)
	cash = post(
		ledger,
		"rehearsal wages",
		-roster_count * Night.ACTOR_WAGE * REHEARSAL_NIGHTS,
		cash,
	)
	if preview_played:
		cash = post(
			ledger,
			"press preview",
			-(Night.wages_for(layout) + Night.NIGHTLY_OVERHEAD + Night.upkeep_for(layout)),
			cash,
		)
	return {
		ledger = ledger,
		cash = cash,
		awareness = alloc.marketing - push,
		presold = presold,
		preview_sat = -1.0,
	}


static func post(ledger: Array[Dictionary], label: String, amount: float, cash: float) -> float:
	var next := cash + amount
	ledger.append({ label = label, amount = amount, cash = next })
	return next
