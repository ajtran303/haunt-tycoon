extends Node

const NAMED := {
	"handpicked":[true, false, true, false, false, true, false, true, false, true],
	"alternating": [false, true, false, true, false, true, false, true, false, true],
	"front_loaded": [true, true, true, true, true, false, false, false, false, false],
	"no_finale":[true, false, true, false, true, false, true, false, true, false],
	"gap_banked":  [true, false, true, false, true, false, true, false, false, true],
	"pairs": [true, true, false, false, true, true, false, false, false, true],
	"pair_finale": [true, false, true, false, false, true, false, false, true, true],
}

static func spread(scares: int, rooms: int) -> Array:
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
