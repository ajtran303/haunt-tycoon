extends SceneTree

const Night = preload("res://sim/night.gd")
const Layouts = preload("res://sim/layouts.gd")

const DEMAND := 540 # exactly capacity at interval 300: sold out, so only layout varies
const NIGHTS := 20  # average out single-night noise
const ROOMS := 10
const INTERVAL := 300.0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	print("layout | hit avg | satisfaction | profit/night")
	for name in Layouts.NAMED:
		var layout := Layouts.NAMED[name] as Array
		var hits := 0.0
		var sat := 0.0
		var profit := 0.0
		for n in NIGHTS:
			var r: Dictionary = Night.run(layout, INTERVAL, rng, DEMAND)
			hits += r.hit_average
			sat += r.satisfaction
			profit += r.profit
		print("%12s | %7.2f | %5.1f | $%.0f"
			% [name, hits / NIGHTS, sat / NIGHTS, profit / NIGHTS])
	quit()
