const Night = preload("res://sim/night.gd")

const SKILL_SPREAD := 1.5

# Shares, not thresholds: every pool gets this composition exactly via
# Roster.reliability_quota; the rng only shuffles who gets which chance.
# 8-actor roster: 5 @ 0.02 + 2 @ 0.05 + 1 @ 0.12 = 0.32 expected callouts
# per night, matching the old 4 scare rooms x 8% CALLOUT_CHANCE.
const RELIABILITY := [[0.60, 0.02], [0.30, 0.05], [0.10, 0.12]]

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
	return {
		name = full_name,
		skill = skill,
		wage = Night.ACTOR_WAGE,
		callout_chance = 0.0,
		observed_callouts = 0,
	}


static func pick_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()]]
