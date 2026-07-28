# res://tests/test_night.gd
extends SceneTree

const Night = preload("res://sim/night.gd")

const LAYOUT := [true, false, true, false, false, true, false, true, false, true]
const MIN_SEPARATION := 2.0 # rooms between groups

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var actors := LAYOUT.count(true)
	print("layout: %d rooms, %d scares, %d actors\n" % [LAYOUT.size(), actors, actors])
	print("interval | groups | hit average | profit")

	for demand in [450, 1800]:
		print("\ndemand %d (%d groups)" % [demand, demand / 9])
		print("interval | groups | hit average | satisfaction | profit")
		_sweep(demand, actors, rng)
		
	quit()

func _sweep(demand: int, actors: int, rng: RandomNumberGenerator) -> void:
	var best_profit := -INF
	var best_interval := 0

	for interval in range(120, 301, 20):
		var inside := Night.groups_inside(LAYOUT.size(), float(interval))
		var separation := LAYOUT.size() / inside

		if separation < MIN_SEPARATION:
			print("%8d | %.1f groups inside — too tight, skipped" % [interval, inside])
			continue

		var r: Dictionary = Night.run(LAYOUT, float(interval), rng, demand)
		print("%8d | %6d | %8.2f | %5.1f | $%.0f"
			% [interval, r.groups, r.hit_average, r.satisfaction, r.profit])
	
		if r.profit > best_profit:
			best_profit = r.profit
			best_interval = interval
	
	print("\nbest profit at interval %d ($%.0f)" % [best_interval, best_profit])
