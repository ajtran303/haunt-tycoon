const Rooms = preload("res://sim/rooms.gd")

const DEFAULT_TANK := 100.0
const HIT_DRAIN := 25.0
const MISS_DRAIN := 8.0
const RECOVERY := HIT_DRAIN * 0.5
const DEFAULT_CEILING := 85.0
const END_FADE_PER_ROOM := 5.0
const PRIME_ON_HIT := 40.0
const PRIME_DECAY_PER_ROOM := 40.0
const PRIME_SCALE := 0.5
const BORE_FREE_ROOMS := 2
const BORE_PER_ROOM := 4.0

const ANIM_CEILING := 65.0 # an actor that can't be rushed or rested
const EFFECT_CEILING := 40.0 # small guaranteed jolt
const EFFECT_DRAIN := 0.4 # a fog blast isn't a chainsaw: fraction of HIT_DRAIN
const DISTRACT_BONUS := 15.0 # the distractor makes the cue: added hit chance
const CHANCE_CAP := 95.0 # even a perfect setup can whiff


static func run(
	layout: Array,
	rng: RandomNumberGenerator,
	recovery: float = RECOVERY,
	ceiling: float = DEFAULT_CEILING,
	prime_scale: float = PRIME_SCALE,
	tank: float = DEFAULT_TANK,
	depletion: float = 1.0,
) -> Dictionary:
	var r := tank
	var hits := 0
	var actor_hits := 0
	var misses := 0
	var peak := 0.0
	var final_reaction := 0.0
	var rooms_since_scare := 0
	var prime := 0.0
	var boredom := 0.0

	for room in layout:
		match room:
			Rooms.CORRIDOR:
				rooms_since_scare += 1
				if rooms_since_scare > BORE_FREE_ROOMS:
					boredom += BORE_PER_ROOM
				prime = maxf(0.0, prime - PRIME_DECAY_PER_ROOM)
				r = minf(tank, r + recovery)
			Rooms.EFFECT:
				rooms_since_scare = 0
				hits += 1
				var reaction := minf(minf(r, EFFECT_CEILING) + prime * prime_scale, 100.0)
				peak = maxf(peak, reaction)
				final_reaction = reaction
				r -= HIT_DRAIN * EFFECT_DRAIN * depletion
			_:
				rooms_since_scare = 0
				var room_ceiling := ANIM_CEILING if room == Rooms.ANIMATRONIC else ceiling
				var chance := minf(r, room_ceiling)
				if room == Rooms.PAIR_SCARE:
					chance = minf(chance + DISTRACT_BONUS, CHANCE_CAP)
				if rng.randf() * 100.0 < chance:
					hits += 1
					actor_hits += 1
					var reaction := minf(minf(r, room_ceiling) + prime * prime_scale, 100.0)
					peak = maxf(peak, reaction)
					final_reaction = reaction
					r -= HIT_DRAIN * depletion
					prime = PRIME_ON_HIT
				else:
					misses += 1
					final_reaction *= 0.4
					r -= MISS_DRAIN
		r = maxf(0.0, r)

	final_reaction = maxf(0.0, final_reaction - END_FADE_PER_ROOM * rooms_since_scare)

	return { "hits": hits, "actor_hits": actor_hits, "misses": misses, "peak": peak, "boredom": boredom, "final_reaction": final_reaction }
