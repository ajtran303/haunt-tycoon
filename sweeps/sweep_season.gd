extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Town = preload("res://sim/town.gd")

const SEEDS := 10


func _initialize() -> void:
	for preset in Layouts.PRESETS:
		var layout: Array = Layouts.PRESETS[preset]
		print("\n%s (build $%.0f)" % [preset, Night.build_cost_for(layout)])
		print("cash out | avg profit | std dev | min | max")

		# 31 = never pack, 1 = pack from night one
		for cash_out_day in range(1, Night.SEASON_NIGHTS + 2):
			var results := run_season(layout, cash_out_day)
			print(
				"%8d | $%.0f | $%.0f | $%.0f | $%.0f"
				% [cash_out_day, results.mean, results.std, results.worst, results.best]
			)
	quit()


static func interval_for(day: int, cash_out_day: int) -> float:
	return Night.PACKED_INTERVAL if day >= cash_out_day else Night.LOOSE_INTERVAL


func run_season(layout: Array, cash_out_day: int) -> Dictionary:
	var seasons: Array[float] = []
	var final_rep := 0.0

	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345 + s

		var total := -Night.build_cost_for(layout)

		var town := Town.new()
		for night in Night.SEASON_NIGHTS:
			var interval := interval_for(night + 1, cash_out_day)
			var r: Dictionary = Night.run(layout, interval, rng, town.demand())
			total += r.profit
			town.record_night(r.satisfaction)

		seasons.append(total)

		final_rep = town.rep

	var mean := 0.0
	for x in seasons:
		mean += x
	mean /= seasons.size()

	var variance := 0.0
	for x in seasons:
		variance += (x - mean) * (x - mean)
	variance /= seasons.size()

	return {
		"mean": mean,
		"std": sqrt(variance),
		"worst": seasons.min(),
		"best": seasons.max(),
		"final_reputation": final_rep,
	}
