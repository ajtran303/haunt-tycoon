extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")
const Visitors = preload("res://sim/visitors.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")

const DEFAULT_DEMAND := 540
const NIGHTS := 20
const INTERVAL := 300.0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()

	var header := "%12s" % "layout"
	for t in Visitors.TYPES:
		header += " | %13s" % t
	header += " | %5s" % "mixed"
	print(header)

	for preset in Layouts.PRESETS:
		var row := "%12s" % [preset]
		for t in Visitors.TYPES:
			row += " | %13.1f" % _avg_sat(Layouts.PRESETS[preset], t, rng)
		row += " | %5.1f" % _avg_sat(Layouts.PRESETS[preset], "", rng)
		print(row)
	quit()


func _avg_sat(layout: Array, type: String, rng: RandomNumberGenerator) -> float:
	rng.seed = 12345
	var sat := 0.0
	for n in NIGHTS:
		var r: Dictionary = Night.run(layout, INTERVAL, rng, DEFAULT_DEMAND, Walkthrough.PRIME_SCALE, type)
		sat += r.satisfaction
	return sat / NIGHTS
