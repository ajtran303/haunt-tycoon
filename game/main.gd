extends Control

const Night = preload("res://sim/night.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")

const STARTING_CASH := 45_000.0
const ROOM_SLOTS := 10

const ROOM_COLORS := {
	Rooms.CORRIDOR: Color(0.32, 0.32, 0.36),
	Rooms.SCARE: Color(0.58, 0.16, 0.16),
	Rooms.PAIR_SCARE: Color(0.42, 0.12, 0.50),
	Rooms.ANIMATRONIC: Color(0.16, 0.32, 0.58),
	Rooms.EFFECT: Color(0.10, 0.46, 0.40),
}

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
		b.set_meta("type", type)
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


func slot_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	return sb


func start_season() -> void:
	night = 1
	layout = []
	for i in ROOM_SLOTS:
		layout.append(Rooms.CORRIDOR)
	town = Town.new()
	cash = STARTING_CASH - Night.build_cost_for(layout)
	%RunButton.text = "Run night"
	%RunButton.disabled = false
	%NightLog.clear()
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
	%CashLabel.add_theme_color_override("font_color", Color.INDIAN_RED if cash < 0.0 else Color.WHITE)
	%NightLabel.text = "Oct %d" % night if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween"

	for i in layout.size():
		%SlotRow.get_child(i).text = TOOLS[layout[i]]
		var b: Button = %SlotRow.get_child(i)
		b.text = TOOLS[layout[i]].to_upper()
		b.add_theme_stylebox_override("normal", slot_style(ROOM_COLORS[layout[i]]))
		b.add_theme_stylebox_override("hover", slot_style(ROOM_COLORS[layout[i]].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(ROOM_COLORS[layout[i]].darkened(0.15)))

	for b in %ToolBar.get_children():
		b.disabled = Night.BUILD_COST[b.get_meta("type")] > cash

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
	var color := "66bb6a" if r.profit >= 0.0 else "ef5350"
	%NightLog.append_text(
		"[b]Oct %d[/b]  %d visitors. %s [color=#%s]$%.0f[/color]\n"
		% [night, r.groups * Night.GROUP_SIZE, crowd_word(r.satisfaction), color, r.profit]
	)
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
