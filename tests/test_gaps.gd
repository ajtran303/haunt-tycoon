extends SceneTree

const Walkthrough = preload("res://sim/walkthrough.gd")

const RUNS := 10_000

const PACKED := [true, true, true, true, true, false, false, false, false, false]
const SPREAD := [true, false, true, false, true, false, true, false, true, false]


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var packed := _average(PACKED, rng)
	var spread := _average(SPREAD, rng)
	print("packed %.2f | spread %.2f | gap %+.2f" % [packed, spread, spread - packed])

	quit()


func _average(layout: Array, rng: RandomNumberGenerator) -> float:
	var total := 0
	for i in RUNS:
		total += Walkthrough.run(layout, rng)
	return float(total) / RUNS
