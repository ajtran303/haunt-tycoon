extends SceneTree

const Night = preload("res://sim/night.gd")

const LAYOUT := [true, false, true, false, false, true, false, true, false, true]
const NIGHTS := 30
const START_DEMAND := 1800
const MAX_DEMAND := 3600
const MIN_DEMAND := 90 # floor: night.run divides by groups, 0 groups crashes
const BREAK_EVEN := 60.0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var actors := LAYOUT.count(true)

	for sensitivity in [100.0, 200.0, 400.0]:
		print("\nsensitivity %d | interval | final demand | season profit" % int(sensitivity))
		for interval in range(120, 301, 60):
			var demand := START_DEMAND
			var season := 0.0
			for night in NIGHTS:
				var r: Dictionary = Night.run(LAYOUT, float(interval), actors, rng, demand)
				season += r.profit
				demand = int(demand * (1.0 + (r.satisfaction - BREAK_EVEN) / sensitivity))
				demand = clampi(demand, MIN_DEMAND, MAX_DEMAND)
			print("%8d | %8d | %12d | $%.0f" % [int(sensitivity), interval, demand, season])
	
	quit()
