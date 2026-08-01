const Night = preload("res://sim/night.gd")

const REHEARSAL_NIGHTS := 7
const PRESALE_DISCOUNT := 0.2
const PRESALE_PUSH_SHARE := 0.5 # marketing split: rest is awareness
const PRESALE_PUSH_PER_TICKET := 20.0 # push dollars to presell one ticket

const PREVIEW_WEIGHT := 0.5 # how much the blurb moves opening belief
const PREVIEW_DEMAND := 90 # press and comps: ten groups

const SEASON_GOALS := [
	  { name = "loan paid", cash = 0.0 },
	  { name = "solid season", cash = 300_000.0 },
	  { name = "local legend", cash = 330_000.0 },
]


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
