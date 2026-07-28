extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")

const NIGHTS := 30
const START_DEMAND := 500
const MAX_DEMAND := 3600
const MIN_DEMAND := 90

const SEEDS := 10

const LOOSE := 300.0
const PACKED := 120.0


func _initialize() -> void:
	for name in Layouts.NAMED:
		print("\n%s" % name)
		print("cash out | avg profit | std dev | min | max")

		# 31 = never pack, 1 = pack from night one
		# Fine-sweep alternative when narrowing a peak: range(25, 32)
		for cash_out_day in range(1, 32):
			var results := run_season(Layouts.NAMED[name], cash_out_day)
			print(
				"%8d | $%.0f | $%.0f | $%.0f | $%.0f"
				% [cash_out_day, results.mean, results.std, results.worst, results.best]
			)
	quit()


static func interval_for(day: int, cash_out_day: int) -> float:
	return PACKED if day >= cash_out_day else LOOSE


func run_season(layout: Array, cash_out_day: int) -> Dictionary:
	var seasons: Array[float] = []

	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345 + s

		var demand := START_DEMAND
		var total := 0.0

		for night in NIGHTS:
			var interval := interval_for(night + 1, cash_out_day)
			var r: Dictionary = Night.run(layout, interval, rng, demand)
			total += r.profit
			demand = clampi(Night.next_demand(demand, r.satisfaction), MIN_DEMAND, MAX_DEMAND)

		seasons.append(total)

	var mean := 0.0
	for x in seasons:
		mean += x
	mean /= seasons.size()

	var variance := 0.0
	for x in seasons:
		variance += (x - mean) * (x - mean)
	variance /= seasons.size()

	return { "mean": mean, "std": sqrt(variance), "worst": seasons.min(), "best": seasons.max() }
