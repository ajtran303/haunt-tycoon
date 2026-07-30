const Actor = preload("res://sim/actor.gd")


static func pool(rng: RandomNumberGenerator, size: int, tier: float) -> Array[Dictionary]:
	var taken := { }
	var out: Array[Dictionary] = []
	for i in size:
		var a := Actor.make(rng, tier)
		while taken.has(a.name):
			a.name = Actor.pick_name(rng)
		taken[a.name] = true
		out.append(a)
	return out


static func auto_hire(
	candidates: Array[Dictionary],
	headcount: int,
	bench: int,
) -> Array[Dictionary]:
	var hired := candidates.duplicate()
	hired.sort_custom(
		func(a, b):
			return a.skill > b.skill,
	)
	return hired.slice(0, headcount + bench)
