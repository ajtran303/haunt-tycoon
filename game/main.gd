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

const PACES := { "Loose": 300.0, "Brisk": 200.0, "Packed": 120.0 }

var interval: float = PACES["Loose"]

var cash: float
var night: int
var layout: Array
var town
var selected_tool: String = Rooms.SCARE
var rng := RandomNumberGenerator.new()

var capacity_hints := 0


func _ready() -> void:
	rng.randomize()
	_build_toolbar()
	_build_slot_row()
	_build_pace_bar()
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
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_slot_pressed.bind(i))
		%SlotRow.add_child(b)


func _build_pace_bar() -> void:
	var pace_group := ButtonGroup.new()
	for pace_name in PACES:
		var b := Button.new()
		b.set_meta("interval", PACES[pace_name])
		b.toggle_mode = true
		b.button_group = pace_group
		b.text = pace_name
		b.button_pressed = PACES[pace_name] == interval
		b.pressed.connect(
			func():
				interval = PACES[pace_name]
				refresh(),
		)
		%PaceBar.add_child(b)


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
	capacity_hints = 0
	%RunButton.text = "Run night"
	%RunButton.disabled = false
	%NightLog.clear()
	interval = PACES["Loose"]
	for b in %PaceBar.get_children():
		b.button_pressed = b.get_meta("interval") == interval
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
	%CashLabel.add_theme_color_override(
		"font_color",
		Color.INDIAN_RED if cash < 0.0 else Color.WHITE,
	)
	%NightLabel.text = "Oct %d" % night if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween"

	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		b.text = TOOLS[layout[i]].to_upper()
		b.add_theme_stylebox_override("normal", slot_style(ROOM_COLORS[layout[i]]))
		b.add_theme_stylebox_override("hover", slot_style(ROOM_COLORS[layout[i]].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(ROOM_COLORS[layout[i]].darkened(0.15)))

	for b in %ToolBar.get_children():
		b.disabled = Night.BUILD_COST[b.get_meta("type")] > cash

	%CostPreview.text = "staff %d, $%.0f wages + upkeep tonight" % [
		Night.staff_for(layout),
		Night.wages_for(layout) + Night.upkeep_for(layout) + Night.NIGHTLY_OVERHEAD,
	]

	var strain := "actors fully reset"
	if interval <= PACES["Packed"]:
		strain = "actors sprinting between scares"
	elif interval <= PACES["Brisk"]:
		strain = "actors hustling"
	%PaceLabel.text = "Line pace: up to %d groups, %s" % [
		int(Night.NIGHT_SECONDS / interval),
		strain,
	]

	%BlueprintNote.visible = night == 1


func _on_run_night() -> void:
	var demand: int = town.demand()
	var capacity := int(Night.NIGHT_SECONDS / interval)
	var r: Dictionary = Night.run(layout, interval, rng, demand)
	var sold_out: bool = demand / Night.GROUP_SIZE > capacity
	town.record_night(r.satisfaction)
	var color := "66bb6a" if r.profit >= 0.0 else "ef5350"
	var line := "[b]Oct %d[/b]  %d visitors. %s [color=#%s]$%.0f[/color]" % [
		night,
		r.groups * Night.GROUP_SIZE,
		crowd_word(r.satisfaction),
		color,
		r.profit,
	]
	if sold_out:
		line += " [color=#e0a458]Sold out! Line down the block.[/color]"
		if interval > PACES["Packed"] and capacity_hints < 2:
			capacity_hints += 1
			line += " [color=#8d99ae]A faster line pace would admit more.[/color]"
	%RunButton.disabled = true
	%ResetButton.disabled = true
	var cash_before := cash
	cash += r.profit
	var visitors: int = r.groups * Night.GROUP_SIZE
	var tween := create_tween()
	var duration := clampf(1.5 + r.groups * 0.03, 1.5, 5.0)
	tween.tween_method(_night_tick.bind(cash_before, visitors), 0.0, 1.0, duration)
	tween.tween_callback(_night_finish.bind(line))


func _night_tick(t: float, cash_before: float, visitors: int) -> void:
	%CashLabel.text = "$%.0f" % lerpf(cash_before, cash, t)
	%NightLabel.text = "Oct %d | %d visitors so far" % [night, int(visitors * t)]
	for i in %SlotRow.get_child_count():
		var b: Button = %SlotRow.get_child(i)
		b.modulate = Color(1.4, 1.4, 1.4) if i == int(t * 40.0) % 10 else Color.WHITE


func _night_finish(line: String) -> void:
	%RunButton.disabled = false
	%ResetButton.disabled = false

	for b in %SlotRow.get_children():
		b.modulate = Color.WHITE
	%NightLog.append_text(line + "\n")
	night += 1
	if cash < -10_000.0:
		%NightLog.append_text("[color=#ef5350]The bank calls your loan. Season over.[/color]\n")
		%RunButton.text = "Bankrupt: $%.0f" % cash
		%RunButton.disabled = true
		refresh()
		return
	if night == 2:
		%NightLog.append_text(
			"[color=#8d99ae]Construction locked in. Rebuilding now costs full price, no refunds.[/color]\n"
		)
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
