const STARTING_RECEPTIVENESS := 100.0
const HIT_COST := 25.0
const MISS_COST := 8.0
const RECOVERY := 12.0

static func run(layout: Array, rng: RandomNumberGenerator) -> int:
	var r := STARTING_RECEPTIVENESS
	var hits := 0
	for has_scare in layout:
		if has_scare:
			if rng.randf() * 100.0 < r:
				hits += 1
				r -= HIT_COST
			else:
				r -= MISS_COST
		else:
			r = minf(STARTING_RECEPTIVENESS, r + RECOVERY)
		r = maxf(0.0, r)
	return hits
