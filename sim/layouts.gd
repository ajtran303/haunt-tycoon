const NAMED := {
	"handpicked": ["a", "g", "a", "g", "g", "a", "g", "a", "g", "a"],
	"alternating": ["g", "a", "g", "a", "g", "a", "g", "a", "g", "a"],
	"front_loaded": ["a", "a", "a", "a", "a", "g", "g", "g", "g", "g"],
	"no_finale": ["a", "g", "a", "g", "a", "g", "a", "g", "a", "g"],
	"gap_banked": ["a", "g", "a", "g", "a", "g", "a", "g", "g", "a"],
	"pairs": ["a", "a", "g", "g", "a", "a", "g", "g", "g", "a"],
	"pair_finale": ["a", "g", "a", "g", "g", "a", "g", "g", "a", "a"],
	"sparse": ["a", "g", "g", "g", "a", "g", "g", "g", "g", "a"],
	"dense": ["a", "g", "a", "a", "g", "a", "g", "a", "g", "a"],
	"pair_bank": ["p", "g", "g", "a", "g", "g", "a", "g", "g", "a"], # 5 actors in 4 rooms: the two-slot claim
	"anim_mid": ["a", "g", "n", "g", "n", "g", "a", "g", "g", "a"], # tempo-immune middle
	"effect_finale": ["a", "g", "a", "g", "a", "g", "a", "g", "g", "e"], # guaranteed ending: variance insurance
}


static func spread(scares: int, rooms: int) -> Array:
	var layout := []
	var acc := 0
	for i in rooms:
		acc += scares
		if acc >= rooms:
			acc -= rooms
			layout.append("a")
		else:
			layout.append("g")
	return layout
