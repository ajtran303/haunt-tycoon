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
	ceilings: Array = [],
	events: Variant = null,
) -> Dictionary:
	var current_tank := tank
	var hits := 0
	var actor_hits := 0
	var misses := 0
	var peak := 0.0
	var final_reaction := 0.0
	var rooms_since_scare := 0
	var prime := 0.0
	var boredom := 0.0

	for i in layout.size():
		var room: String = layout[i]
		match room:
			Rooms.CORRIDOR:
				rooms_since_scare += 1
				var bore_delta := BORE_PER_ROOM if rooms_since_scare > BORE_FREE_ROOMS else 0.0
				if rooms_since_scare > BORE_FREE_ROOMS:
					boredom += bore_delta
				if events != null:
					events.append({ room = i, kind = "corridor", reaction = 0.0, bore = bore_delta })
				prime = maxf(0.0, prime - PRIME_DECAY_PER_ROOM)
				current_tank = minf(tank, current_tank + recovery)
			Rooms.EFFECT:
				rooms_since_scare = 0
				hits += 1
				var reaction := minf(minf(current_tank, EFFECT_CEILING) + prime * prime_scale, 100.0)
				peak = maxf(peak, reaction)
				final_reaction = reaction
				current_tank -= HIT_DRAIN * EFFECT_DRAIN * depletion
				if events != null:
					events.append({ room = i, kind = "effect_hit", reaction = reaction, bore = 0.0 })
			_:
				rooms_since_scare = 0
				var base: float = ceilings[i] if not ceilings.is_empty() else ceiling
				var room_ceiling: float = ANIM_CEILING if room == Rooms.ANIMATRONIC else base
				var chance := minf(current_tank, room_ceiling)
				if room == Rooms.PAIR_SCARE:
					chance = minf(chance + DISTRACT_BONUS, CHANCE_CAP)
				var is_anim := room == Rooms.ANIMATRONIC
				var kind: String
				var hit_reaction := 0.0
				if rng.randf() * 100.0 < chance:
					hits += 1
					actor_hits += 1
					var reaction := minf(minf(current_tank, room_ceiling) + prime * prime_scale, 100.0)
					peak = maxf(peak, reaction)
					final_reaction = reaction
					current_tank -= HIT_DRAIN * depletion
					prime = PRIME_ON_HIT
					kind = "anim_hit" if is_anim else "hit"
					hit_reaction = reaction
				else:
					misses += 1
					final_reaction *= 0.4
					current_tank -= MISS_DRAIN
					kind = "anim_whiff" if is_anim else "whiff"
				if events != null:
					events.append({ room = i, kind = kind, reaction = hit_reaction, bore = 0.0 })
		current_tank = maxf(0.0, current_tank)

	final_reaction = maxf(0.0, final_reaction - END_FADE_PER_ROOM * rooms_since_scare)

	return {
		"hits": hits,
		"actor_hits": actor_hits,
		"misses": misses,
		"peak": peak,
		"boredom": boredom,
		"final_reaction": final_reaction,
	}
