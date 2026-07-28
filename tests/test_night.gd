extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Rooms = preload("res://sim/rooms.gd")

const LAYOUT_NAME := "gap_banked"


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var layout: Array = Layouts.PRESETS[LAYOUT_NAME]
	var actors := 0
	for room in layout:
		match room:
			Rooms.SCARE:
				actors += 1
			Rooms.PAIR_SCARE:
				actors += 2
	print(
		"layout: %s | %d rooms | %d actors | %d staff"
		% [LAYOUT_NAME, layout.size(), actors, Night.staff_for(layout)]
	)

	for demand in [450, 1800]:
		print("\ndemand %d (%d groups)" % [demand, demand / 9])
		print("interval | groups | hit avg | real hits | satisfaction | profit")
		_sweep(layout, demand, rng)

	quit()


func _sweep(layout: Array, demand: int, rng: RandomNumberGenerator) -> void:
	var best_profit := -INF
	var best_interval := 0

	for interval in range(120, 301, 20):
		var inside: float = Night.concurrent_groups(layout.size(), float(interval))
		var separation := layout.size() / inside

		if separation < Night.MIN_SEPARATION:
			print("%8d | %.1f groups inside — too tight, skipped" % [interval, inside])
			continue

		var r: Dictionary = Night.run(layout, float(interval), rng, demand)
		print(
			"%8d | %6d | %7.2f | %9.2f | %12.1f | $%.0f"
			% [interval, r.groups, r.hit_average, r.real_hit_average, r.satisfaction, r.profit]
		)

		if r.profit > best_profit:
			best_profit = r.profit
			best_interval = interval

	print("\nbest profit at interval %d ($%.0f)" % [best_interval, best_profit])
