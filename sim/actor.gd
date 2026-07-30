const Night = preload("res://sim/night.gd")

const SKILL_SPREAD := 1.5

# 60% steady, 30% average, 10% flaky. Mean 0.039; two-actor room ≈ 7.8%,
# matching the old 8% CALLOUT_CHANCE per scare room.
const RELIABILITY := [[0.60, 0.02], [0.90, 0.05], [1.0, 0.12]]

const FIRST := [
	"Marcus",
	"Dana",
	"Theo",
	"Priya",
	"Wes",
	"June",
	"Rocco",
	"Alma",
	"Sasha",
	"Gideon",
	"Beth",
	"Hollis",
	"Ivy",
	"Cole",
	"Nadia",
	"Otis",
	"Lena",
	"Quinn",
	"Farrah",
	"Ezra",
]

const LAST := [
	"Webb",
	"Okafor",
	"Reyes",
	"Lindqvist",
	"Park",
	"Delacroix",
	"Huang",
	"Marsh",
	"Ortiz",
	"Kaminski",
	"Boone",
	"Ferreira",
	"Nash",
	"Ito",
	"Crowley",
	"Vance",
	"Sloan",
	"Adeyemi",
	"Quick",
	"Thorne",
]


static func make(rng: RandomNumberGenerator, tier: float) -> Dictionary:
	var full_name := pick_name(rng)
	var skill := clampf(rng.randfn(tier * 10.0, SKILL_SPREAD), 0.0, 10.0)
	var callout_chance := roll_reliability(rng)
	return {
		name = full_name,
		skill = skill,
		wage = Night.ACTOR_WAGE,
		callout_chance = callout_chance,
		observed_callouts = 0,
	}


static func pick_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]


static func roll_reliability(rng: RandomNumberGenerator) -> float:
	var r := rng.randf()
	for bucket in RELIABILITY:
		if r < bucket[0]:
			return bucket[1]
	return RELIABILITY[-1][1]
