extends SceneTree

const Night = preload("res://sim/night.gd")
const Casting = preload("res://sim/casting.gd")
const Allocation = preload("res://sim/allocation.gd")
const Preseason = preload("res://sim/preseason.gd")

const SIX_SCARE := ["a", "g", "a", "g", "a", "a", "g", "a", "g", "a"]
const SEED := 12345
const SEEDS := 20

const REFERENCE := { build = 11_000.0, quality = 9_000.0, depth = 5_000.0, marketing = 6_000.0 }
const SQUEEZE_BAND := 3_500.0 # honest-run trough: -9550

const BUILD_HEAVY := { build = 23_000.0, quality = 0.0, depth = 0.0, marketing = 1_000.0 }
const CAST_HEAVY := { build = 9_500.0, quality = 14_000.0, depth = 5_000.0, marketing = 1_000.0 }

var failed := 0


func _initialize() -> void:
	squeeze_band()
	presale_conservation()
	phase_parity()
	season_goals_ordered()
	print("PASS: preseason invariants hold" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


func squeeze_band() -> void:
	var phases: Dictionary = Allocation.run_preseason(REFERENCE, SEED)
	var trough: float = Night.STARTING_CASH
	for entry in phases.ledger:
		trough = minf(trough, entry.cash)
	check(trough >= Night.LOAN_LIMIT, "pre-season bankrupts: trough $%.0f" % trough)
	check(
		trough <= Night.LOAN_LIMIT + SQUEEZE_BAND,
		"squeeze gone soft: trough $%.0f, band tops at $%.0f"
		% [trough, Night.LOAN_LIMIT + SQUEEZE_BAND],
	)
	for s in SEEDS:
		var p: Dictionary = Allocation.run_preseason(REFERENCE, SEED + s)
		var t: Array[Dictionary] = Allocation.run_season(
			REFERENCE,
			SEED + s,
			Casting.REASSIGN,
			true,
			null,
			p,
		)
		var low: float = t[0].cash
		for night in t:
			low = minf(low, night.cash)
		check(low > Night.LOAN_LIMIT, "seed %d: October dips to $%.0f" % [SEED + s, low])


func presale_conservation() -> void:
	var discounted: Dictionary = Allocation.run_preseason(REFERENCE, SEED)
	var full_price: Dictionary = Allocation.run_preseason(REFERENCE, SEED, true, 0.0)
	var a: Array[Dictionary] = Allocation.run_season(
		REFERENCE,
		SEED,
		Casting.REASSIGN,
		true,
		null,
		discounted,
	)
	var b: Array[Dictionary] = Allocation.run_season(
		REFERENCE,
		SEED,
		Casting.REASSIGN,
		true,
		null,
		full_price,
	)
	check(
		total_redeemed(a) == discounted.presold,
		"pool didn't drain: %d of %d redeemed" % [total_redeemed(a), discounted.presold],
	)
	var give_back: float = discounted.presold * Night.TICKET_PRICE * Preseason.PRESALE_DISCOUNT
	check(
		absf((b[-1].cash - a[-1].cash) - give_back) < 0.01,
		"gross with presales != without minus the discount",
	)


func phase_parity() -> void:
	for alloc in [REFERENCE, BUILD_HEAVY, CAST_HEAVY]:
		var neutral := {
			ledger = [],
			cash = Night.STARTING_CASH \
					- Night.build_cost_for(Allocation.layout_for(alloc.build)) \
					- alloc.quality \
					- alloc.marketing,
			awareness = alloc.marketing,
			presold = 0,
			preview_sat = -1.0,
		}
		var slider: Array[Dictionary] = Allocation.run_season(alloc, SEED)
		var phased: Array[Dictionary] = Allocation.run_season(
			alloc,
			SEED,
			Casting.REASSIGN,
			true,
			null,
			neutral,
		)
		var same := slider.size() == phased.size()
		if same:
			for i in slider.size():
				if slider[i].cash != phased[i].cash or slider[i].revenue != phased[i].revenue:
					same = false
					break
		check(same, "neutral phases diverge from the slider path for %s" % str(alloc))


func season_goals_ordered() -> void:
	check(Preseason.SEASON_GOALS[0].cash == 0.0, "anchor tier is not loan payoff")
	for i in range(1, Preseason.SEASON_GOALS.size()):
		check(
			Preseason.SEASON_GOALS[i].cash > Preseason.SEASON_GOALS[i - 1].cash,
			"season goals out of order",
		)


func total_redeemed(trajectory: Array[Dictionary]) -> int:
	var total := 0
	for night in trajectory:
		total += night.redeemed
	return total


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)
