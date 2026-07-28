const STARTING_RECEPTIVENESS := 100.0
const HIT_COST := 25.0
const MISS_COST := 8.0
const RECOVERY := HIT_COST * 0.5
const CEILING := 85.0
const END_FADE_PER_ROOM := 5.0
const PRIME_ON_HIT := 40.0
const PRIME_DECAY_PER_ROOM := 40
const PRIME_SCALE := 0.5
const BORE_FREE_GAPS := 2
const BORE_PER_ROOM := 4.0

static func run(
		layout: Array,
		rng: RandomNumberGenerator,
		recovery: float = RECOVERY,
		ceiling: float = CEILING,
		prime_scale: float = PRIME_SCALE,
		tank: float = STARTING_RECEPTIVENESS,
		depletion: float = 1.0
	) -> Dictionary:
	
	var r := tank
	var hits := 0
	var misses := 0
	var peak := 0.0
	var end := 0.0
	var rooms_since_scare := 0
	var arousal := 0.0
	var boredom := 0.0
	
	for has_scare in layout:
		if has_scare:
			rooms_since_scare = 0
			var chance := minf(r, ceiling)
			if rng.randf() * 100.0 < chance:
				hits += 1
				var reaction := minf(minf(r, ceiling) + arousal * prime_scale, 100.0)
				peak = maxf(peak, reaction)
				end = reaction
				r -= HIT_COST * depletion
				arousal = PRIME_ON_HIT
			else:
				misses += 1
				end = 0.0
				r -= MISS_COST
		else:
			rooms_since_scare += 1
			if rooms_since_scare > BORE_FREE_GAPS:
				boredom += BORE_PER_ROOM
			arousal = maxf(0.0, arousal - PRIME_DECAY_PER_ROOM)
			r = minf(tank, r + recovery)
		r = maxf(0.0, r)
		
	end = maxf(0.0, end - END_FADE_PER_ROOM * rooms_since_scare)
	
	return {"hits": hits, "misses": misses, "peak": peak, "boredom": boredom, "end": end}
