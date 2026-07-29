extends Control

const Night = preload("res://sim/night.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")

const STARTING_CASH := 45_000.0
const ROOM_SLOTS := 10

const TOOLS := {
	Rooms.CORRIDOR: "Corridor",
	Rooms.SCARE: "Scare",
	Rooms.PAIR_SCARE: "Pair scare",
	Rooms.ANIMATRONIC: "Animatronic",
	Rooms.EFFECT: "Effect",
}

var cash: float
var night: int
var layout: Array
var town
var selected_tool: String = Rooms.SCARE
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_toolbar()
	_build_slot_row()
	%PaceSlider.value_changed.connect(
		func(_v):
			refresh(),
	)
	%RunButton.pressed.connect(_on_run_night)
	%ResetButton.pressed.connect(start_season)
	start_season()


func _build_toolbar() -> void:
	var tool_group := ButtonGroup.new()
	for type in TOOLS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = tool_group
		b.text = "%s $%d" % [TOOLS[type], Night.BUILD_COST[type]]
		b.pressed.connect(
			func():
				selected_tool = type,
		)
		%ToolBar.add_child(b)


func _build_slot_row() -> void:
	for i in ROOM_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.pressed.connect(_on_slot_pressed.bind(i))
		%SlotRow.add_child(b)


func start_season() -> void:
	night = 1
	layout = []
	for i in ROOM_SLOTS:
		layout.append(Rooms.CORRIDOR)
	town = Town.new()
	cash = STARTING_CASH - Night.build_cost_for(layout)
	%RunButton.text = "Run night"
	%RunButton.disabled = false
	%ResultsLabel.text = ""
	refresh()


func _on_slot_pressed(i: int) -> void:
	if layout[i] == selected_tool:
		return
	var cost: float = Night.BUILD_COST[selected_tool]
	if night == 1:
		cost -= Night.BUILD_COST[layout[i]] # blueprint phase: swap refunds the old room
	if cost > cash:
		return
	cash -= cost
	layout[i] = selected_tool
	refresh()


func refresh() -> void:
	%CashLabel.text = "$%.0f" % cash
	%NightLabel.text = "Oct %d" % night if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween"
	for i in layout.size():
		%SlotRow.get_child(i).text = TOOLS[layout[i]]
	var interval: float = %PaceSlider.value
	%PaceLabel.text = "group every %ds" % int(interval)
	%CostPreview.text = "staff %d, $%.0f wages + upkeep tonight" % [
		Night.staff_for(layout),
		Night.wages_for(layout) + Night.upkeep_for(layout) + Night.NIGHTLY_OVERHEAD,
	]


func _on_run_night() -> void:
	var r: Dictionary = Night.run(layout, %PaceSlider.value, rng, town.demand())
	cash += r.profit
	town.record_night(r.satisfaction)
	%ResultsLabel.text = "%d visitors. %s Profit $%.0f" % [
		r.groups * Night.GROUP_SIZE,
		crowd_word(r.satisfaction),
		r.profit,
	]
	night += 1
	if night > Night.SEASON_NIGHTS:
		%RunButton.text = "Season over: $%.0f" % cash
		%RunButton.disabled = true
	refresh()


func crowd_word(sat: float) -> String:
	if sat >= 80.0:
		return "The crowd left raving."
	if sat >= 60.0:
		return "Good screams tonight."
	if sat >= 45.0:
		return "Mixed reactions."
	if sat >= 30.0:
		return "People left flat."
	return "Walkouts and refund demands."
