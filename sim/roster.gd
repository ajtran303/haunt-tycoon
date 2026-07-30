const Actor = preload("res://sim/actor.gd")


static func pool(rng: RandomNumberGenerator, size: int, tier: float) -> Array[Dictionary]:
	var chances := reliability_quota(size, rng)
	var taken := { }
	var out: Array[Dictionary] = []
	for i in size:
		var a := Actor.make(rng, tier)
		while taken.has(a.name):
			a.name = Actor.pick_name(rng)
		taken[a.name] = true
		a.callout_chance = chances[i]
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


static func roll_callouts(roster: Array[Dictionary], rng: RandomNumberGenerator) -> Array:
	var absent := []
	for i in roster.size():
		if rng.randf() < roster[i].callout_chance:
			absent.append(i)
	return absent


# Largest-remainder quota over Actor.RELIABILITY shares, shuffled with rng.
# Every pool has the anchor composition exactly; only identity is random.
static func reliability_quota(size: int, rng: RandomNumberGenerator) -> Array:
	var counts := []
	var remainders := []
	var used := 0
	for bucket in Actor.RELIABILITY:
		var exact: float = bucket[0] * size
		counts.append(int(exact))
		remainders.append(exact - int(exact))
		used += int(exact)
	while used < size:
		var best := 0
		for i in remainders.size():
			if remainders[i] >= remainders[best]: # ties break flaky-ward
				best = i
		counts[best] += 1
		remainders[best] = -1.0
		used += 1
	var chances := []
	for i in counts.size():
		for j in counts[i]:
			chances.append(Actor.RELIABILITY[i][1])
	for i in range(chances.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: float = chances[i]
		chances[i] = chances[j]
		chances[j] = tmp
	return chances
