extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")

const NIGHTS := 30
const START_DEMAND := 500
const MAX_DEMAND := 3600
const MIN_DEMAND := 90 # floor: night.run divides by groups, 0 groups crashes

const SEEDS := 10

func _initialize() -> void:
	for name in Layouts.NAMED:
		print("\n%s" % name)
		print("interval | avg final demand | avg profit | min | max")

		for interval in range(240, 301, 20):
			var profit_sum := 0.0
			var demand_sum := 0
			var worst := INF
			var best := -INF

			for s in SEEDS:
				var rng := RandomNumberGenerator.new()
				rng.seed = 12345 + s

				var demand := START_DEMAND
				var season := 0.0
				for night in NIGHTS:
					var r: Dictionary = Night.run(Layouts.NAMED[name], float(interval), rng, demand)
					season += r.profit
					demand = clampi(Night.next_demand(demand, r.satisfaction), MIN_DEMAND, MAX_DEMAND)

				profit_sum += season
				demand_sum += demand
				worst = minf(worst, season)
				best = maxf(best, season)
			print("%8d | %10d | $%.0f | $%.0f | $%.0f"
				% [interval, demand_sum / SEEDS, profit_sum / SEEDS, worst, best])
	
	quit()
