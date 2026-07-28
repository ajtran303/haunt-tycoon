const Night = preload("res://sim/night.gd")

const WOM_DELAY := 3 # nights for word of mouth to circulate
const STARTING_REP := 55.0 # a new haunt: unknown quantity, curiosity crowd

var rep: float
var heard: Array[float] # what the town believes, oldest first


func _init(starting_rep := STARTING_REP) -> void:
	rep = starting_rep
	heard = []
	for i in WOM_DELAY:
		heard.append(starting_rep)


func demand() -> int:
	return Night.demand_for(heard[0] if heard.size() > 0 else rep)


func record_night(sat: float) -> void:
	rep = Night.next_reputation(rep, sat)
	if heard.size() > 0:
		heard.remove_at(0)
		heard.append(rep)
