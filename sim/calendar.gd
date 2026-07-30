const FIRST_WEEKDAY := 4 # Oct 1 is a Thursday (0 = Sunday)
const HALLOWEEN_WEEK_START := 25

const DAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

# Sun, Mon, Tue, Wed, Thu, Fri, Sat
const DAY_WEIGHTS := [1.05, 0.45, 0.35, 0.55, 0.8, 1.6, 2.0]
const HALLOWEEN_WEEK_MULT := 1.35
const HALLOWEEN_WEIGHT := 2.2 # night 31 flat, regardless of weekday

const WEATHER := {
	"clear": { mult = 1.0, chance = 0.70 },
	"drizzle": { mult = 0.75, chance = 0.20 },
	"rain": { mult = 0.45, chance = 0.10 },
}


static func weekday(night: int) -> int: # night is 1-based
	return (FIRST_WEEKDAY + night - 1) % 7


static func weight_for(night: int) -> float:
	if night == 31:
		return HALLOWEEN_WEIGHT
	var w: float = DAY_WEIGHTS[weekday(night)]
	if night >= HALLOWEEN_WEEK_START:
		w *= HALLOWEEN_WEEK_MULT
	return w


static func is_counted(night: int) -> bool:
	return night >= HALLOWEEN_WEEK_START or weekday(night) in [5, 6]


static func roll_season(seed_val: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 200_000 # own stream; don't disturb night or callout draws
	var season: Array[String] = []
	for i in 31:
		var roll := rng.randf()
		var acc := 0.0
		for w in WEATHER:
			acc += WEATHER[w].chance
			if roll < acc:
				season.append(w)
				break
	return season
