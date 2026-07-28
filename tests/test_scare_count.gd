extends SceneTree

const Walkthrough = preload("res://sim/walkthrough.gd")

const RUNS := 10_000
const ROOMS := 12


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var prev := 0.0
	for scares in range(1, ROOMS + 1):
		var hits := _average(_spread_layout(scares, ROOMS), rng)
		print("scares %2d | hits %.2f | marginal %+.2f" % [scares, hits, hits - prev])
		prev = hits

	quit()


func _average(layout: Array, rng: RandomNumberGenerator) -> float:
	var total := 0
	for i in RUNS:
		total += Walkthrough.run(layout, rng)
	return float(total) / RUNS


func _spread_layout(scares: int, rooms: int) -> Array:
	var layout := []
	var acc := 0
	for i in rooms:
		acc += scares
		if acc >= rooms:
			acc -= rooms
			layout.append(true)
		else:
			layout.append(false)
	return layout
