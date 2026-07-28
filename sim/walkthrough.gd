const STARTING_RECEPTIVENESS := 100.0
const HIT_COST := 25.0
const MISS_COST := 8.0
const RECOVERY := HIT_COST * 0.5
const CEILING := 85.0
const END_FADE_PER_ROOM := 5.0

static func run(layout: Array, rng: RandomNumberGenerator, recovery: float = RECOVERY, ceiling: float = CEILING) -> Dictionary:
	var r := STARTING_RECEPTIVENESS
	var hits := 0
	var misses := 0
	var peak := 0.0
	var end := 0.0
	var rooms_since_scare := 0
	
	for has_scare in layout:
		if has_scare:
			rooms_since_scare = 0
			var chance := minf(r, ceiling)
			if rng.randf() * 100.0 < chance:
				hits += 1
				var reaction := minf(r, ceiling)
				peak = maxf(peak, reaction)
				end = reaction
				r -= HIT_COST
			else:
				misses -= 1
				end = 0.0
				r -= MISS_COST
		else:
			rooms_since_scare += 1
			r = minf(STARTING_RECEPTIVENESS, r + recovery)
		r = maxf(0.0, r)
	
	end = maxf(0.0, end - END_FADE_PER_ROOM * rooms_since_scare)
	
	return {"hits": hits, "misses": misses, "peak": peak, "end": end}
